defmodule LolApi.RateLimiter.RedisCommand do
  @moduledoc """
  Domain-aware redis commands
  """

  @type keys :: list(String.t())
  @type ttls :: list(non_neg_integer())
  @type limit_check_result :: {:allowed} | {:throttled, non_neg_integer()}

  @doc """
  Atomic operation with Lua script needed for rate limiter.
  """
  def inc_with_exp(key, ttl) do
    script = """
    local count = redis.call("INCR", KEYS[1])
    if count == 1 then
    redis.call("EXPIRE", KEYS[1], tonumber(ARGV[1]))
    end
    return count
    """

    [
      "EVAL",
      script,
      # how many redis keys will be listed below, other will be arguments
      "1",
      # one key as stated above, available in Lua as KEYS[1]
      key,
      # will be ARGV[1] in Lua script
      to_string(ttl)
    ]
  end

  def check_keys_existance(keys) when is_list(keys) do
    [
      "EXISTS" | keys
    ]
  end

  @doc """
  Atomically checks rate limit counters against their limits, and updates them if allowed.

  ## Arguments

  - `counter_keys`: Redis keys tracking request counts per window.
  - `limit_keys`: Redis keys storing the configured limit values.
  - `ttls`: TTLs (in seconds) for each counter key’s window.
  """
  @spec check_and_increment(keys, keys, ttls) :: limit_check_result()
  def check_and_increment(counter_keys, limit_keys, ttls) do
    script =
      """
      for i = 1, #KEYS do
        local count = tonumber(redis.call("GET", KEYS[i]) or "0")
        local limit = tonumber(redis.call("GET", ARGV[i]) or "0")

        if count >= limit then
          local ttl = redis.call("TTL", KEYS[i])
          return {"throttled", ttl}
        end
      end

      -- passed all checks, now increment + expire if needed
      for i = 1, #KEYS do
        local ttl = tonumber(ARGV[i + #KEYS])
        local count = redis.call("INCR", KEYS[i])
        if count == 1 then
          redis.call("EXPIRE", KEYS[i], ttl)
        end
      end

      return {"allowed"}
      """

    List.flatten([
      "EVAL",
      script,
      # how many from the list of keys will be in KEYS, 
      # other will be in ARGV 
      to_string(length(counter_keys)),
      counter_keys,
      limit_keys,
      Enum.map(ttls, &to_string/1)
    ])
  end
end
