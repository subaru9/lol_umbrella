defmodule LolApi.RateLimit.KeyValueParser do
  @moduledoc """
  Parses Redis keys with values into LimitEntry
  """

  alias LolApi.RateLimit.{KeyParser, LimitEntry}

  @type limit_entry :: LimitEntry.t()
  @type limit_entries :: [limit_entry()]
  @type key_value_flat_list :: [String.t()]

  @doc """
  Parses a flat list returned by Redis
  into a list of `%LimitEntry{}` maps — one for each window value
  found in the :policy_windows entries.

  ## Example

      iex> flat = [
      ...>   "riot:v1:policy:na1:/lol/summoner:application:windows", "120,1",
      ...>   "riot:v1:policy:na1:/lol/summoner:method:windows", "10"
      ...> ]
      iex> LolApi.RateLimit.KeyValueParser.parse_policy_windows(flat)
      [
        %LolApi.RateLimit.LimitEntry{
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
        %LolApi.RateLimit.LimitEntry{
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
        %LolApi.RateLimit.LimitEntry{
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
  @spec parse_policy_windows(key_value_flat_list) :: limit_entries()
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
      iex> LolApi.RateLimit.KeyValueParser.parse_policy_limits(flat_list)
      [
        %LolApi.RateLimit.LimitEntry{
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
        %LolApi.RateLimit.LimitEntry{
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
        %LolApi.RateLimit.LimitEntry{
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
  @spec parse_policy_limits(key_value_flat_list()) :: limit_entries()
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
  Parses a flat list of live Redis counter data into a list of `%LimitEntry{}` structs.

  The flat list is structured as repeating triplets:
    1. the Redis key (e.g., `"lol_api:v1:live:euw1:/lol/summoner:method:window:1"`)
    2. the current count
    3. the remaining TTL in seconds

  ## Example

      iex> flat = [
      ...>   "lol_api:v1:live:euw1:/lol/summoner:method:window:1", "1", "20", "59",
      ...>   "lol_api:v1:live:euw1:/lol/summoner:method:window:120", "3", "100", "118"
      ...> ]
      iex> LolApi.RateLimit.KeyValueParser.parse_live_counters_with_values(flat)
      [
        %LolApi.RateLimit.LimitEntry{
          routing_val: :euw1,
          endpoint: "/lol/summoner",
          limit_type: :method,
          window_sec: 1,
          count: 1,
          count_limit: 20,
          ttl: 59,
          source: :live
        },
        %LolApi.RateLimit.LimitEntry{
          routing_val: :euw1,
          endpoint: "/lol/summoner",
          limit_type: :method,
          window_sec: 120,
          count: 3,
          count_limit: 100,
          ttl: 118,
          source: :live
        }
      ]
  """
  @spec parse_live_counters_with_values(key_value_flat_list()) :: limit_entries()
  def parse_live_counters_with_values(flat_list) do
    flat_list
    |> Enum.chunk_every(4)
    |> Enum.map(fn [live_key, count, count_limit, ttl] ->
      live_key
      |> KeyParser.parse()
      |> LimitEntry.update!(%{count: count, count_limit: count_limit, ttl: ttl})
    end)
  end

  @doc """
  Parses a cooldown key and TTL pair into a `%LimitEntry{}`.

  Adds `ttl` and marks `source: :cooldown`.

  ## Example

      iex> key = "lol_api:v1:cooldown:na1:/lol/summoner:method"
      iex> LolApi.RateLimit.KeyValueParser.parse_cooldown(key, 42)
      %LolApi.RateLimit.LimitEntry{
        routing_val: :na1,
        endpoint: "/lol/summoner",
        limit_type: :method,
        ttl: 42,
        source: :cooldown
      }
  """
  @spec parse_cooldown(key :: String.t(), ttl :: non_neg_integer()) :: limit_entry()
  def parse_cooldown(key, ttl) do
    key
    |> KeyParser.parse()
    |> LimitEntry.update!(%{ttl: ttl})
  end
end
