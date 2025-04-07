defmodule LolApi.RateLimiter.RedisCommand do
  @moduledoc """
  Domain-aware redis commands
  """

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
end
