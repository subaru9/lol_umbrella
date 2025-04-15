defmodule LolApi.RateLimiter.KeyValueParser do
  alias LolApi.RateLimiter.{LimitEntry, KeyParser}

  @doc """
  Parses a flat list returned by Redis
  into a list of `%LimitEntry{}` maps — one for each window value
  found in the :policy_windows entries.

  ## Example

      iex> flat = [
      ...>   "riot:v1:policy:na1:/lol/summoner:app:windows", "120,1",
      ...>   "riot:v1:policy:na1:/lol/summoner:method:windows", "10"
      ...> ]
      iex> KeyValueParser.parse_policy_windows(flat)
      [
        %{limit_type: :app, routing_val: "na1", endpoint: "/lol/summoner", window_sec: 120},
        %{limit_type: :app, routing_val: "na1", endpoint: "/lol/summoner", window_sec: 1},
        %{limit_type: :method, routing_val: "na1", endpoint: "/lol/summoner", window_sec: 10}
      ]
  """
  def parse_policy_windows(flat_list) do
    flat_list
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn [key, val] ->
      parsed_key = KeyParser.parse(key)

      val
      |> String.split(",")
      |> Enum.map(fn window_sec ->
        parsed_key
        |> Map.put(:window_sec, window_sec)
        |> LimitEntry.create!()
      end)
    end)
  end
end
