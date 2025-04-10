defmodule LolApi.RateLimiter.RedisCommand do
  @moduledoc """
  Domain-aware redis commands
  """
  alias LolApi.RateLimiter.KeyBuilder

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

  @doc """
  Builds a single Redis MSET command to cache all policy definitions in one call.

  It merges `:policy_windows` and per-window `:policy_limit` keys into a flat structure.

  ## Example

      iex> grouped = %{
      ...>   {"na1", "/lol/summoner", :app} => [
      ...>     %{window_sec: 120, count_limit: 100},
      ...>     %{window_sec: 1, count_limit: 20}
      ...>   ],
      ...>   {"na1", "/lol/summoner", :method} => [
      ...>     %{window_sec: 10, count_limit: 50}
      ...>   ]
      ...> }
      iex> LolApi.RateLimiter.RedisCommand.build_policy_mset_command(grouped)
      [
        "MSET",
        "riot:v1:policy:na1:/lol/summoner:app:windows", "120,1",
        "riot:v1:policy:na1:/lol/summoner:method:windows", "10",
        "riot:v1:policy:na1:/lol/summoner:app:window:120:limit", "100",
        "riot:v1:policy:na1:/lol/summoner:app:window:1:limit", "20",
        "riot:v1:policy:na1:/lol/summoner:method:window:10:limit", "50"
      ]

  """
  @spec build_policy_mset_command(%{
          {String.t(), String.t(), atom()} => [
            %{window_sec: pos_integer(), count_limit: pos_integer()}
          ]
        }) :: [String.t()]
  def build_policy_mset_command(grouped) do
    policy_windows = KeyBuilder.build_policy_window_entries(grouped)
    limits = KeyBuilder.build_limit_entries(grouped)

    ["MSET"] ++
      Enum.flat_map(policy_windows ++ limits, fn {k, v} -> [k, v] end)
  end
end
