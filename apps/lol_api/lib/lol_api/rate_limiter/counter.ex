defmodule LolApi.RateLimiter.Counter do
  @moduledoc """
  """
  alias LolApi.RateLimiter.{
    HeaderParser,
    KeyBuilder,
    KeyValueParser,
    LimitEntry,
    RedisCommand
  }

  alias SharedUtils.Redis

  @pool_name :lol_api_rate_limiter_pool
  @limit_types [:app, :method]

  @type redis_key :: String.t()
  @type ttl_seconds :: non_neg_integer()
  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type limit_type :: :app | :method
  @type limit_entry :: LimitEntry.t()
  @type limit_entries :: [limit_entry()]
  @type allowed :: {:ok, :allowed}
  @type throttled :: {:error, :throttled, pos_integer()}
  @type resp_headers :: [{String.t(), String.t()}]

  def limit_types, do: @limit_types

  # add telemetry later
  # Counter: how many times each key is incremented
  # Distribution / histogram: counter values
  @spec increment(redis_key(), ttl_seconds()) :: non_neg_integer() | {:error, ErrorMessage.t()}
  def increment(key, ttl) do
    key
    |> RedisCommand.inc_with_exp(ttl)
    |> Redis.with_pool(@pool_name, & &1)
  end

  @doc """
  Checks if rate-limiting policy exists in Redis.

  We only check `:policy_windows` keys — they act as presence markers
  for a fully defined policy (which always includes associated limits).
  """
  @spec policy_known?(routing_val(), endpoint()) :: {:ok, boolean()} | {:error, ErrorMessage.t()}
  def policy_known?(routing_val, endpoint) do
    routing_val
    |> KeyBuilder.build_policy_window_keys(endpoint)
    |> RedisCommand.check_keys_existance()
    |> Redis.with_pool(@pool_name, &{:ok, &1 === 2})
  end

  @doc """
  Checks if Redis holds the `:policy_windows` keys for `routing_val` and `endpoint`.

  `:policy_windows` defines window durations for each `{routing_val, endpoint, limit_type}`.

  Example Redis key:
    "riot:v1:policy:na1:/lol/summoner:app:windows" => "1,120"
    # → check 1s and 120s windows for the `:app` limit on that route

  Returns a list of `%LimitEntry{}` structs like:

      %LolApi.RateLimiter.LimitEntry{
        routing_val: :na1,
        endpoint: "/lol/summoner",
        limit_type: :app,
        window_sec: 120,
        count: 0,
        count_limit: nil,
        request_time: nil,
        retry_after: nil
      }
  """
  @spec load_policy_windows(routing_val(), endpoint()) :: limit_entries
  def load_policy_windows(routing_val, endpoint) do
    routing_val
    |> KeyBuilder.build_policy_window_keys(endpoint)
    |> RedisCommand.build_policy_window_command()
    |> Redis.with_pool(@pool_name, & &1)
    |> KeyValueParser.parse_policy_windows()
  end

  @spec track_request(routing_val, endpoint, resp_headers) ::
          allowed | throttled | {:error, ErrorMessage.t()}
  def track_request(routing_val, endpoint, resp_headers) do
    case policy_known?(routing_val, endpoint) do
      {:ok, true} ->
        load_policy_windows(routing_val, endpoint)
        |> RedisCommand.check_and_increment_from_entries()
        |> Redis.with_pool(@pool_name, fn
          ["allowed"] -> {:ok, :allowed}
          ["throttled", ttl] -> {:error, :throttled, ttl}
        end)

      {:ok, false} ->
        limit_entries = HeaderParser.parse(resp_headers)
        :ok = set_policy(limit_entries)
        {:ok, :allowed}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Writes rate-limiting policy into Redis using a Redis `MSET` command.

  It receives a list of `%LimitEntry{}` structs that define the limits
  per `{routing_val, endpoint, limit_type, window_sec}`.

  Example structure:

      [
        %LimitEntry{
          routing_val: "na1",
          endpoint: "/lol/summoner",
          limit_type: :app,
          window_sec: 1,
          count_limit: 20
        },
        %LimitEntry{
          routing_val: "na1",
          endpoint: "/lol/summoner",
          limit_type: :app,
          window_sec: 120,
          count_limit: 100
        }
      ]

  This writes two types of Redis keys:

    • `:policy_windows` — defines which window durations apply per `{routing_val, endpoint, limit_type}`.

        Example:
          "riot:v1:policy:na1:/lol/summoner:app:windows" => "1,120"

    • `:policy_limit` — defines how many requests are allowed per window.

        Examples:
          "riot:v1:policy:na1:/lol/summoner:app:window:1:limit"   => "20"
          "riot:v1:policy:na1:/lol/summoner:app:window:120:limit" => "100"

  Together, these define the canonical policy for the operational phase.
  """
  @spec set_policy(limit_entries()) :: :ok | {:error, ErrorMessage.t()}
  def set_policy(limit_entries) do
    limit_entries
    |> RedisCommand.build_policy_mset_command()
    |> Redis.with_pool(@pool_name, fn "OK" -> :ok end)
  end
end
