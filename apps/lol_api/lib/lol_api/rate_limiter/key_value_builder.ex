defmodule LolApi.RateLimiter.KeyValueBuilder do
  @moduledoc """
  Build Redis compatible key with values to be used in Redis commands
  """
  alias LolApi.RateLimiter.{KeyBuilder, LimitEntry}

  @doc """
  Builds one `:policy_limit` Redis key for each `%LimitEntry{}`.

  Each key uniquely identifies a `{routing_val, endpoint, limit_type, window_sec}` tuple,
  and its value is the quota (as a string) — suitable for use in a Redis `MSET` command.

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
      iex> LolApi.RateLimiter.KeyValueBuilder.build_policy_limit_entries(entries)
      [
        {"riot:v1:policy:na1:/lol/summoner:app:window:120:limit", "100"},
        {"riot:v1:policy:na1:/lol/summoner:app:window:1:limit", "20"},
        {"riot:v1:policy:na1:/lol/summoner:method:window:10:limit", "50"}
      ]
  """
  @spec build_policy_limit_entries([LimitEntry.t()]) :: list({String.t(), String.t()})
  def build_policy_limit_entries(entries) do
    Enum.map(entries, fn entry ->
      {
        KeyBuilder.build(:policy_limit, entry),
        Integer.to_string(entry.count_limit)
      }
    end)
  end

  @doc """
  Builds one `:policy_windows` Redis key for each unique `{limit_type}`.

  Each value is a comma-separated list of window durations (e.g. "10,120"),
  used to describe the window sizes defined for that limit type.

  ## Example

      iex> entries = [
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :app,
      ...>     window_sec: 120
      ...>   },
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :app,
      ...>     window_sec: 1
      ...>   },
      ...>   %LolApi.RateLimiter.LimitEntry{
      ...>     routing_val: "na1",
      ...>     endpoint: "/lol/summoner",
      ...>     limit_type: :method,
      ...>     window_sec: 10
      ...>   }
      ...> ]
      iex> LolApi.RateLimiter.KeyValueBuilder.build_policy_window_entries(entries)
      [
        {"riot:v1:policy:na1:/lol/summoner:app:windows", "120,1"},
        {"riot:v1:policy:na1:/lol/summoner:method:windows", "10"}
      ]
  """
  @spec build_policy_window_entries([LimitEntry.t()]) :: list({String.t(), String.t()})
  def build_policy_window_entries(entries) do
    entries
    |> Enum.group_by(& &1.limit_type)
    |> Enum.map(fn {_limit_type, entries} ->
      {
        KeyBuilder.build(:policy_windows, hd(entries)),
        Enum.map_join(entries, ",", & &1.window_sec)
      }
    end)
  end
end
