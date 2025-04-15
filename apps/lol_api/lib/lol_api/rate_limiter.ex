defmodule LolApi.RateLimiter do
  @moduledoc """
  RateLimiter context for delegating rate-limiting operations
  to the configured limiter type.
  """
  alias LolApi.RateLimiter.{KeyBuilder, RedisCommand, LimitEntry}
  alias SharedUtils.Redis

  @pool_name :lol_api_rate_limiter_pool
  @limit_types [:app, :method]

  @type redis_key :: String.t()
  @type ttl_seconds :: non_neg_integer()
  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type limit_type :: :app | :method

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

  @spec policy_known?(routing_val(), endpoint()) :: boolean() | {:error, ErrorMessage.t()}
  def policy_known?(routing_val, endpoint) do
    routing_val
    |> KeyBuilder.build_policy_windows(endpoint)
    |> RedisCommand.check_keys_existance()
    |> Redis.with_pool(@pool_name, &(&1 === 2))
  end

  defp load_policy_windows(routing_val, endpoint) do
    routing_val
    |> KeyBuilder.build_policy_windows(endpoint)
    |> RedisCommand.fetch_policy_windows_with_keys()
    |> Redis.with_pool(@pool_name, & &1)
  end

  def track_request(routing_val, endpoint, riot_headers) do
    if policy_known?(routing_val, endpoint) do
      # operational phase
    else
      # bootstrap phase
    end
  end

  @doc """
  Caches windows durations and their limits in Redis
  """
  @spec cache_policy_defs([LimitEntry.t()]) :: :ok
  def cache_policy_defs(limit_entries) do
    limit_entries
    |> Enum.group_by(& &1.limit_type)
    |> RedisCommand.build_policy_mset_command()
    |> Redis.with_pool(@pool_name, & &1)
  end
end
