defmodule LolApi.RateLimiter.RedisCommand do
  @moduledoc """
  Domain-aware redis commands
  """
  alias LolApi.RateLimiter.{KeyBuilder, KeyValueBuilder, LimitEntry}

  @type key :: String.t()
  @type keys :: list(key)
  @type window_keys :: list(String.t())
  @type ttl :: non_neg_integer()
  @type ttls :: list(ttl)
  @type command :: [String.t()]
  @type limit_entries :: [LimitEntry.t()]

  @doc """
  Builds Redis `SETEX` command for cooldown.

  ## Examples

      iex> RedisCommand.build_cooldown_setex_command("lol_api:v1:cooldown:na1:application", 120)
      ["SETEX", "lol_api:v1:cooldown:na1:application", "120", "120"]
  """
  @spec build_cooldown_setex_command(key, ttl) :: command()
  def build_cooldown_setex_command(key, ttl) do
    ttl_str = to_string(ttl)

    [
      "SETEX",
      key,
      ttl_str,
      ttl_str
    ]
  end

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
  Builds a single Redis MSET command to cache all policy definitions in one call.

  It merges `:policy_windows` and per-window `:policy_limit` keys into a flat structure.

  ## Example

      iex> entries = [
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :app,
      ...>     window_sec: 120,
      ...>     count_limit: 100
      ...>   },
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :app,
      ...>     window_sec: 1,
      ...>     count_limit: 20
      ...>   },
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :method,
      ...>     window_sec: 10,
      ...>     count_limit: 50
      ...>   }
      ...> ]
      iex> LolApi.RateLimiter.RedisCommand.build_policy_mset_command(entries)
      [
        "MSET",
        "riot:v1:policy:na1:/lol/summoner:app:windows", "120,1",
        "riot:v1:policy:na1:/lol/summoner:method:windows", "10",
        "riot:v1:policy:na1:/lol/summoner:app:window:120:limit", "100",
        "riot:v1:policy:na1:/lol/summoner:app:window:1:limit", "20",
        "riot:v1:policy:na1:/lol/summoner:method:window:10:limit", "50"
      ]
  """
  @spec build_policy_mset_command(limit_entries()) :: command()
  def build_policy_mset_command(entries) do
    policy_windows = KeyValueBuilder.build_policy_window_entries(entries)
    limits = KeyValueBuilder.build_policy_limit_entries(entries)

    ["MSET"] ++
      Enum.flat_map(policy_windows ++ limits, fn {k, v} -> [k, v] end)
  end

  @doc """
  Fetches flat list of `[key, value, key, value]` using Lua script
  ```elixir
  [
  "riot:v1:policy:na1:/lol/summoner:app:windows", "120,1",
  "riot:v1:policy:na1:/lol/summoner:method:windows", "10"
  ]
  ```
  """
  @spec get_keys_with_values(keys) :: command()
  def get_keys_with_values(keys) do
    script = """
    results={}
    for i, key in ipairs(KEYS) do
      val = redis.call("GET", key)
      table.insert(results, key)
      table.insert(results, val)
    end
    return results
    """

    [
      "EVAL",
      script,
      to_string(length(keys)),
      keys
    ]
  end

  @doc """
  Atomically builds the Redis EVAL command from a list of `%LimitEntry{}` structs.

  ## Example

      iex> entries = [
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :app,
      ...>     window_sec: 120,
      ...>     count_limit: 100
      ...>   },
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :app,
      ...>     window_sec: 1,
      ...>     count_limit: 20
      ...>   },
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :method,
      ...>     window_sec: 10,
      ...>     count_limit: 50
      ...>   }
      ...> ]
      iex> result = LolApi.RateLimiter.RedisCommand.check_and_increment_from_entries(entries)
      iex> [
      ...>   "EVAL",
      ...>   _script,
      ...>   "3",
      ...>   "lol_api:v1:live:na1:/lol/summoner:method:window:10",
      ...>   "lol_api:v1:live:na1:/lol/summoner:app:window:1",
      ...>   "lol_api:v1:live:na1:/lol/summoner:app:window:120",
      ...>   "riot:v1:policy:na1:/lol/summoner:method:window:10:limit",
      ...>   "riot:v1:policy:na1:/lol/summoner:app:window:1:limit",
      ...>   "riot:v1:policy:na1:/lol/summoner:app:window:120:limit",
      ...>   "10",
      ...>   "1",
      ...>   "120"
      ...> ] = result
  """
  @spec check_and_increment(limit_entries()) :: command()
  def check_and_increment(limit_entries) do
    {counters, limits, ttls} = prepare_check_payload(limit_entries)

    check_and_increment_from_keys(counters, limits, ttls)
  end

  @spec check_and_increment_from_keys(keys, keys, ttls) :: command()
  defp check_and_increment_from_keys(counter_keys, limit_keys, ttls) do
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
      # Redis keys tracking request counts per window.
      counter_keys,
      # Redis keys storing the limit values.
      limit_keys,
      # TTLs (in seconds) for each counter key’s window.
      Enum.map(ttls, &to_string/1)
    ])
  end

  @spec prepare_check_payload(limit_entries) :: {keys, keys, ttls}
  defp prepare_check_payload(limit_entries) do
    Enum.reduce(limit_entries, {[], [], []}, fn entry,
                                                {live_counter_acc, policy_limit_acc, windows_acc} ->
      {
        [KeyBuilder.build(:live_counter, entry) | live_counter_acc],
        [KeyBuilder.build(:policy_limit, entry) | policy_limit_acc],
        [entry.window_sec | windows_acc]
      }
    end)
  end
end
