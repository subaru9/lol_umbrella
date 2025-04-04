defmodule LolApi.RateLimiter.KeyBuilder do
  @our_prefix "lol_api"
  @riot_prefix "riot"
  @version "v1"
  @joiner ":"

  @type header_data :: %{
          required(:limit_type) => atom(),
          required(:window_sec) => pos_integer(),
          required(:count_limit) => non_neg_integer(),
          required(:count) => non_neg_integer(),
          required(:request_time) => DateTime.t()
        }
  @type key_type :: :live_counter | :authoritative_counter | :policy_limit | :policy_windows

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
  @spec build(key_type(), String.t(), String.t(), header_data()) :: String.t()
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
end
