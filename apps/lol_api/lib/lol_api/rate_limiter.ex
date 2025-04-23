defmodule LolApi.RateLimiter do
  @moduledoc """
  RateLimiter context for delegating rate-limiting operations
  to the configured limiter type.
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

  @spec policy_known?(routing_val(), endpoint()) :: {:ok, boolean()} | {:error, ErrorMessage.t()}
  def policy_known?(routing_val, endpoint) do
    routing_val
    |> KeyBuilder.build_policy_window_keys(endpoint)
    |> RedisCommand.check_keys_existance()
    |> Redis.with_pool(@pool_name, &{:ok, &1 === 2})
  end

  @doc """
  Using Lua script fetches policy windows keys with durations
  and parses them into `[%LimitEntry{}]` for further processing
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
        :ok = cache_policy_defs(limit_entries)
        {:ok, :allowed}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Caches windows durations and their limits in Redis
  """
  @spec cache_policy_defs([LimitEntry.t()]) :: :ok | {:error, ErrorMessage.t()}
  def cache_policy_defs(limit_entries) do
    limit_entries
    |> RedisCommand.build_policy_mset_command()
    |> Redis.with_pool(@pool_name, fn "OK" -> :ok end)
  end
end
