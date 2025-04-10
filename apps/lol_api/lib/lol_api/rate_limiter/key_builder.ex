defmodule LolApi.RateLimiter.KeyBuilder do
  alias LolApi.RateLimiter

  @our_prefix "lol_api"
  @riot_prefix "riot"
  @version "v1"
  @joiner ":"

  @type key_type :: :live_counter | :authoritative_counter | :policy_limit | :policy_windows
  @type header_data :: %{
          required(:limit_type) => atom(),
          required(:window_sec) => pos_integer(),
          required(:count_limit) => non_neg_integer(),
          required(:count) => non_neg_integer(),
          required(:request_time) => DateTime.t()
        }
  @type limit_type :: %{
          required(:limit_type) => :app | :method
        }
  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type key :: String.t()

  @doc """
  Builds a Redis-compatible key based on the counter type and associated metadata.

  ## Example

      iex> LolApi.RateLimiter.KeyBuilder.build(
      ...>   :policy_limit,
      ...>   "euw1",
      ...>   "/lol/match/v5/matches",
      ...>   %{
      ...>     limit_type: :app,
      ...>     window_sec: 120,
      ...>     count_limit: 100,
      ...>     count: 20,
      ...>     request_time: ~U[2025-04-01 18:15:26Z]
      ...>   }
      ...> )
      "riot:v1:policy:euw1:/lol/match/v5/matches:app:window:120:limit"

  """
  @spec build(key_type(), String.t(), String.t(), header_data() | limit_type()) :: String.t()
  def build(type, routing_val, endpoint, header_data) do
    {prefix, mode, suffix} = parts_by_type(type, header_data)

    ([
       prefix,
       @version,
       mode,
       routing_val,
       endpoint,
       header_data[:limit_type]
     ] ++
       suffix)
    |> Enum.join(@joiner)
  end

  defp parts_by_type(:live_counter, header_data) do
    {@our_prefix, :live, [:window, header_data[:window_sec]]}
  end

  defp parts_by_type(:authoritative_counter, header_data) do
    {@riot_prefix, :authoritative, [:window, header_data[:window_sec]]}
  end

  defp parts_by_type(:policy_limit, header_data) do
    {@riot_prefix, :policy, [:window, header_data[:window_sec], :limit]}
  end

  defp parts_by_type(:policy_windows, _header_data) do
    {@riot_prefix, :policy, [:windows]}
  end

  @doc """
  Keys will be used in determining if it is the bootstrap or operational phase

  ## Example

    iex> LolApi.RateLimiter.KeyBuilder.build_policy_windows_keys("na1", "/lol/summoner")
    [
      "riot:v1:policy:na1:/lol/summoner:app:windows",
      "riot:v1:policy:na1:/lol/summoner:method:windows",
    ]

  """
  @spec build_policy_windows_keys(routing_val(), endpoint()) :: list(key)
  def build_policy_windows_keys(routing_val, endpoint) do
    Enum.map(
      RateLimiter.limit_types(),
      &build(:policy_windows, routing_val, endpoint, %{limit_type: &1})
    )
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
    policy_windows = build_policy_window_entries(grouped)
    limits = build_limit_entries(grouped)

    ["MSET"] ++
      Enum.flat_map(policy_windows ++ limits, fn {k, v} -> [k, v] end)
  end

  @doc """
  Builds one `:policy_windows` key per limit type group.

  Each value is a comma-separated list of window durations (e.g. "10,120"),
  used to store which windows apply to each `{routing_val, endpoint, limit_type}` combination.

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
      iex> LolApi.RateLimiter.RedisCommand.build_policy_window_entries(grouped)
      [
        {"riot:v1:policy:na1:/lol/summoner:app:windows", "120,1"},
        {"riot:v1:policy:na1:/lol/summoner:method:windows", "10"}
      ]

  """
  @spec build_policy_window_entries(map()) :: list({String.t(), String.t()})
  defp build_policy_window_entries(grouped) do
    Enum.map(grouped, fn {{routing_val, endpoint, limit_type}, entries} ->
      {
        KeyBuilder.build(:policy_windows, routing_val, endpoint, %{limit_type: limit_type}),
        Enum.map_join(entries, ",", & &1.window_sec)
      }
    end)
  end

  @doc """
  Builds one `:policy_limit` key for each entry.

  Each key corresponds to a specific `{routing_val, endpoint, limit_type, window_sec}` tuple.
  The associated value is the request quota, stored as a string so it can be used directly in Redis `MSET`.

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
      iex> LolApi.RateLimiter.RedisCommand.build_limit_entries(grouped)
      [
        {"riot:v1:policy:na1:/lol/summoner:app:window:120:limit", "100"},
        {"riot:v1:policy:na1:/lol/summoner:app:window:1:limit", "20"},
        {"riot:v1:policy:na1:/lol/summoner:method:window:10:limit", "50"}
      ]

  """
  @spec build_limit_entries(map()) :: list({String.t(), String.t()})
  defp build_limit_entries(grouped) do
    Enum.flat_map(grouped, fn {{routing_val, endpoint, limit_type}, entries} ->
      Enum.map(entries, fn %{window_sec: window_sec, count_limit: count_limit} ->
        {
          KeyBuilder.build(:policy_limit, routing_val, endpoint, %{
            limit_type: limit_type,
            window_sec: window_sec
          }),
          Integer.to_string(count_limit)
        }
      end)
    end)
  end
end
