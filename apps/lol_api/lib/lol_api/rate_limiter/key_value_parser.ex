defmodule LolApi.RateLimiter.KeyValueParser do
  @moduledoc """
  Parses Redis keys with values into LimitEntry
  """

  alias LolApi.RateLimiter.{KeyParser, LimitEntry}

  @doc """
  Parses a flat list returned by Redis
  into a list of `%LimitEntry{}` maps — one for each window value
  found in the :policy_windows entries.

  ## Example

      iex> flat = [
      ...>   "riot:v1:policy:na1:/lol/summoner:application:windows", "120,1",
      ...>   "riot:v1:policy:na1:/lol/summoner:method:windows", "10"
      ...> ]
      iex> LolApi.RateLimiter.KeyValueParser.parse_policy_windows(flat)
      [
        %LolApi.RateLimiter.LimitEntry{
          endpoint: "/lol/summoner",
          limit_type: :application,
          routing_val: :na1,
          window_sec: 120,
          count: 0,
          count_limit: nil,
          request_time: nil,
          retry_after: nil,
          ttl: nil,
          adjusted_ttl: nil,
          source: :policy
        },
        %LolApi.RateLimiter.LimitEntry{
          endpoint: "/lol/summoner",
          limit_type: :application,
          routing_val: :na1,
          window_sec: 1,
          count: 0,
          count_limit: nil,
          request_time: nil,
          retry_after: nil,
          ttl: nil,
          adjusted_ttl: nil,
          source: :policy
        },
        %LolApi.RateLimiter.LimitEntry{
          endpoint: "/lol/summoner",
          limit_type: :method,
          routing_val: :na1,
          window_sec: 10,
          count: 0,
          count_limit: nil,
          request_time: nil,
          retry_after: nil,
          ttl: nil,
          adjusted_ttl: nil,
          source: :policy
        }
      ]
  """
  def parse_policy_windows(flat_list) do
    flat_list
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn [key, val] ->
      limit_entry = KeyParser.parse(key)

      val
      |> String.split(",")
      |> Enum.map(&LimitEntry.update!(limit_entry, %{window_sec: &1}))
    end)
  end

  @doc """
  Parses Redis `:policy_limit` keys with their values into `%LimitEntry{}` structs.

  ## Examples

      iex> flat_list = [
      ...>   "riot:v1:policy:na1:/lol/summoner:application:window:1:limit", "20",
      ...>   "riot:v1:policy:na1:/lol/summoner:application:window:120:limit", "100",
      ...>   "riot:v1:policy:na1:/lol/summoner:method:window:10:limit", "50"
      ...> ]
      iex> LolApi.RateLimiter.KeyValueParser.parse_policy_limits(flat_list)
      [
        %LolApi.RateLimiter.LimitEntry{
          routing_val: :na1,
          endpoint: "/lol/summoner",
          limit_type: :application,
          window_sec: 1,
          count_limit: 20,
          count: 0,
          request_time: nil,
          retry_after: nil,
          ttl: nil,
          adjusted_ttl: nil,
          source: :policy
        },
        %LolApi.RateLimiter.LimitEntry{
          routing_val: :na1,
          endpoint: "/lol/summoner",
          limit_type: :application,
          window_sec: 120,
          count_limit: 100,
          count: 0,
          request_time: nil,
          retry_after: nil,
          ttl: nil,
          adjusted_ttl: nil,
          source: :policy
        },
        %LolApi.RateLimiter.LimitEntry{
          routing_val: :na1,
          endpoint: "/lol/summoner",
          limit_type: :method,
          window_sec: 10,
          count_limit: 50,
          count: 0,
          request_time: nil,
          retry_after: nil,
          ttl: nil,
          adjusted_ttl: nil,
          source: :policy
        }
      ]
  """
  def parse_policy_limits(flat_list) do
    flat_list
    |> Enum.chunk_every(2)
    |> Enum.map(fn [limit_key, count_limit] ->
      limit_key
      |> KeyParser.parse()
      |> LimitEntry.update!(%{count_limit: count_limit})
    end)
  end

  @doc """
  Parses a cooldown key and TTL pair into a `%LimitEntry{}`.

  Adds `ttl` and marks `source: :cooldown`.

  ## Example

      iex> key = "lol_api:v1:cooldown:na1:/lol/summoner:method"
      iex> LolApi.RateLimiter.KeyValueParser.parse_cooldown(key, 42)
      %LolApi.RateLimiter.LimitEntry{
        routing_val: :na1,
        endpoint: "/lol/summoner",
        limit_type: :method,
        ttl: 42,
        source: :cooldown
      }
  """
  @spec parse_cooldown(key :: String.t(), ttl :: non_neg_integer()) :: LimitEntry.t()
  def parse_cooldown(key, ttl) do
    key
    |> KeyParser.parse()
    |> LimitEntry.update!(%{ttl: ttl})
  end
end
