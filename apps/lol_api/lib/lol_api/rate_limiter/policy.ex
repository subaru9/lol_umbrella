defmodule LolApi.RateLimiter.Policy do
  @moduledoc """
  Handles rate-limiting logic using atomic Redis counters.

  This module enforces request quotas by:

    • Checking if a valid policy exists in Redis
    • Caching policy from Riot headers if missing (bootstrap phase)
    • Tracking requests by incrementing live counters (operational phase)

  It supports multiple time windows and limit types (`:application` and `:method`)
  per `{routing_val, endpoint}` combination.

  The result is a two-phase rate limiter that respects Riot’s dynamic limits
  while minimizing Redis roundtrips.
  """
  alias LolApi.Config
  alias LolApi.RateLimiter

  alias LolApi.RateLimiter.{
    HeaderParser,
    KeyBuilder,
    KeyValueParser,
    LimitEntry,
    RedisCommand
  }

  alias SharedUtils.Redis

  @type redis_key :: String.t()
  @type ttl_seconds :: non_neg_integer()

  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type limit_type :: RateLimiter.limit_type()

  @type limit_entry :: LimitEntry.t()
  @type limit_entries :: [limit_entry()]

  @type allow :: {:allow, limit_entry()}
  @type throttle :: {:throttle, limit_entry()}

  @type headers :: [{String.t(), String.t()}]

  # add telemetry later
  # Counter: how many times each key is incremented
  # Distribution / histogram: counter values
  @spec increment(redis_key(), ttl_seconds()) :: non_neg_integer() | {:error, ErrorMessage.t()}
  def increment(key, ttl) do
    key
    |> RedisCommand.inc_with_exp(ttl)
    |> Redis.with_pool(Config.redis_pool_name(), & &1)
  end

  @doc """
  Checks if rate-limiting policy exists in Redis.

  We only check `:policy_windows` keys — they act as presence markers
  for a fully defined policy (which always includes associated limits).
  """
  @spec known?(routing_val(), endpoint()) :: {:ok, boolean()} | {:error, ErrorMessage.t()}
  def known?(routing_val, endpoint) do
    routing_val
    |> KeyBuilder.build_policy_window_keys(endpoint)
    |> RedisCommand.check_keys_existance()
    |> Redis.with_pool(Config.redis_pool_name(), &{:ok, &1 === 2})
  end

  @doc """
  Checks if Redis holds the `:policy_windows` keys for `routing_val` and `endpoint`.

  `:policy_windows` defines window durations for each `{routing_val, endpoint, limit_type}`.

  Example Redis key:
    "riot:v1:policy:na1:/lol/summoner:application:windows" => "1,120"
    # → check 1s and 120s windows for the `:application` limit on that route

  Returns a list of `%LimitEntry{}` structs like:

      %LolApi.RateLimiter.LimitEntry{
        routing_val: :na1,
        endpoint: "/lol/summoner",
        limit_type: :application,
        window_sec: 120,
        count: 0,
        count_limit: nil,
        request_time: nil,
        retry_after: nil
      }
  """
  @spec load_policy_windows(routing_val(), endpoint()) :: ErrorMessage.t_res(limit_entries())
  def load_policy_windows(routing_val, endpoint) do
    with keys <- KeyBuilder.build_policy_window_keys(routing_val, endpoint),
         command <- RedisCommand.get_keys_with_values(keys) do
      Redis.with_pool(command, Config.redis_pool_name(), fn
        [] ->
          {:error,
           ErrorMessage.not_found(
             "[LolApi.RateLimiter.Policy] Policy windows not found",
             command
           )}

        entries ->
          {:ok, KeyValueParser.parse_policy_windows(entries)}
      end)
    end
  end

  @spec fetch(routing_val(), endpoint()) :: ErrorMessage.t_res(limit_entries())
  def fetch(routing_val, endpoint) do
    with {:ok, limit_entries} <- load_policy_windows(routing_val, endpoint),
         limit_keys <- Enum.map(limit_entries, &KeyBuilder.build(:policy_limit, &1)),
         command <- RedisCommand.get_keys_with_values(limit_keys) do
      Redis.with_pool(command, Config.redis_pool_name(), fn
        [] ->
          {:error,
           ErrorMessage.not_found("[LolApi.RateLimiter.Policy] Policy limits not found", command)}

        flat_list ->
          {:ok, KeyValueParser.parse_policy_limits(flat_list)}
      end)
    end
  end

  @spec enforce(limit_entries()) :: allow() | throttle() | {:error, ErrorMessage.t()}
  def enforce(limit_entries) do
    limit_entries
    |> RedisCommand.check_and_increment()
    |> Redis.with_pool(Config.redis_pool_name(), fn
      ["allow" | flat_list] ->
        {:allow, KeyValueParser.parse_live_counters_with_values(flat_list)}

      ["throttle" | flat_list] ->
        {:throttle, KeyValueParser.parse_live_counters_with_values(flat_list)}
    end)
  end

  @doc """
  Parses Riot rate-limit headers and writes the resulting policy to Redis via `MSET`.

  This function extracts `%LimitEntry{}` structs from the headers using `HeaderParser.parse/1`,
  and then writes both the `:policy_windows` and `:policy_limit` keys.

  Together, these define the canonical policy for the operational phase.

  It writes two types of Redis keys:

    • `:policy_windows` — defines which window durations apply per `{routing_val, endpoint, limit_type}`.

        Example:
          "riot:v1:policy:na1:/lol/summoner:application:windows" => "1,120"

    • `:policy_limit` — defines how many requests are allowed per window.

        Examples:
          "riot:v1:policy:na1:/lol/summoner:application:window:1:limit"   => "20"
          "riot:v1:policy:na1:/lol/summoner:application:window:120:limit" => "100"

  Together, these define the canonical policy for the operational phase.
  """
  @spec set(headers(), routing_val(), endpoint()) :: :ok | {:error, ErrorMessage.t()}
  def set(headers, routing_val, endpoint) do
    headers
    |> HeaderParser.parse()
    |> Enum.map(&LimitEntry.update!(&1, %{routing_val: routing_val, endpoint: endpoint}))
    |> RedisCommand.build_policy_mset_command()
    |> Redis.with_pool(Config.redis_pool_name(), fn "OK" -> :ok end)
  end
end
