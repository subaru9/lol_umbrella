defmodule LolApi.RateLimiter.KeyBuilder do
  alias LolApi.RateLimiter.LimitEntry
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
  Builds a Redis-compatible key from a given `LimitEntry`.

  Supported key types:
    - `:policy_limit`
    - `:policy_windows`
    - `:live_counter`
    - `:authoritative_counter`

  ## Examples

      iex> entry = %LolApi.RateLimiter.LimitEntry{
      ...>   routing_val: "euw1",
      ...>   endpoint: "/lol/match/v5/matches",
      ...>   limit_type: :app,
      ...>   window_sec: 120
      ...> }
      iex> LolApi.RateLimiter.KeyBuilder.build(:policy_limit, entry)
      "riot:v1:policy:euw1:/lol/match/v5/matches:app:window:120:limit"

      iex> LolApi.RateLimiter.KeyBuilder.build(:policy_windows, entry)
      "riot:v1:policy:euw1:/lol/match/v5/matches:app:windows"

      iex> LolApi.RateLimiter.KeyBuilder.build(:live_counter, entry)
      "lol_api:v1:live:euw1:/lol/match/v5/matches:app:window:120"

      iex> LolApi.RateLimiter.KeyBuilder.build(:authoritative_counter, entry)
      "riot:v1:authoritative:euw1:/lol/match/v5/matches:app:window:120"
  """
  @spec build(key_type(), LimitEntry.t()) :: String.t()
  def build(type, %LimitEntry{} = entry) do
    {prefix, mode, suffix} = parts_by_type(type, entry)

    ([
       prefix,
       @version,
       mode,
       entry.routing_val,
       entry.endpoint,
       entry.limit_type
     ] ++
       suffix)
    |> Enum.join(@joiner)
  end

  defp parts_by_type(:live_counter, entry) do
    {@our_prefix, :live, [:window, entry.window_sec]}
  end

  defp parts_by_type(:authoritative_counter, entry) do
    {@riot_prefix, :authoritative, [:window, entry.window_sec]}
  end

  defp parts_by_type(:policy_limit, entry) do
    {@riot_prefix, :policy, [:window, entry.window_sec, :limit]}
  end

  defp parts_by_type(:policy_windows, _entry) do
    {@riot_prefix, :policy, [:windows]}
  end

  @doc """
  Keys will be used in determining if it is the bootstrap or operational phase

  ## Example

    iex> LolApi.RateLimiter.KeyBuilder.build_policy_windows("na1", "/lol/summoner")
    [
      "riot:v1:policy:na1:/lol/summoner:app:windows",
      "riot:v1:policy:na1:/lol/summoner:method:windows",
    ]

  """
  @spec build_policy_windows(routing_val(), endpoint()) :: list(key)
  def build_policy_windows(routing_val, endpoint) do
    Enum.map(
      RateLimiter.limit_types(),
      &build(
        :policy_windows,
        LimitEntry.create!(%{routing_val: routing_val, endpoint: endpoint, limit_type: &1})
      )
    )
  end

  # def build_check_inputs(limit_entries) do
  #   Enum.reduce(limit_entries, {}, fn entry, acc ->
  #     nil
  #   end)
  # end
end
