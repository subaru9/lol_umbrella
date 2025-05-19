defmodule LolApi.RateLimit.KeyBuilder do
  @moduledoc """
  Builds Redis-compatible keys for all rate-limiting operations.

  Supported key types:
    - `:policy_limit`
    - `:policy_windows`
    - `:live_counter`
    - `:authoritative_counter`
    - `:cooldown`

  All keys are namespaced (`riot` or `lol_api`) and versioned (`v1`) for consistency.
  """

  alias LolApi.RateLimit
  alias LolApi.RateLimit.LimitEntry

  @our_prefix "lol_api"
  @riot_prefix "riot"
  @version "v1"
  @joiner ":"

  @type key_type ::
          :live_counter
          | :authoritative_counter
          | :policy_limit
          | :policy_windows
          | :cooldown

  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type key :: String.t()

  @doc """
  Builds a Redis key from a `%LimitEntry{}`.

  Supported key types:

    • `:policy_limit`
    • `:policy_windows`
    • `:live_counter`
    • `:authoritative_counter`
    • `:cooldown`

  Cooldown keys adapt based on limit type:

    - `:application` and `:service` → no endpoint in key
    - `:method` → includes endpoint

  ## Examples

      iex> entry = %LolApi.RateLimit.LimitEntry{
      ...>   routing_val: "euw1",
      ...>   endpoint: "/lol/match/v5/matches",
      ...>   limit_type: :application,
      ...>   window_sec: 120,
      ...>   retry_after: 60
      ...> }
      iex> LolApi.RateLimit.KeyBuilder.build(:policy_limit, entry)
      "riot:v1:policy:euw1:/lol/match/v5/matches:application:window:120:limit"
      iex>
      iex> LolApi.RateLimit.KeyBuilder.build(:policy_windows, entry)
      "riot:v1:policy:euw1:/lol/match/v5/matches:application:windows"
      iex>
      iex> LolApi.RateLimit.KeyBuilder.build(:live_counter, entry)
      "lol_api:v1:live:euw1:/lol/match/v5/matches:application:window:120"
      iex>
      iex> LolApi.RateLimit.KeyBuilder.build(:authoritative_counter, entry)
      "riot:v1:authoritative:euw1:/lol/match/v5/matches:application:window:120"
      iex>
      iex> LolApi.RateLimit.KeyBuilder.build(:cooldown, entry)
      "lol_api:v1:cooldown:euw1:application"

      iex> method_entry = %LolApi.RateLimit.LimitEntry{
      ...>   routing_val: "euw1",
      ...>   endpoint: "/lol/spectator/v3/featured-games",
      ...>   limit_type: :method,
      ...>   retry_after: 30
      ...> }
      iex> LolApi.RateLimit.KeyBuilder.build(:cooldown, method_entry)
      "lol_api:v1:cooldown:euw1:/lol/spectator/v3/featured-games:method"

      iex> service_entry = %LolApi.RateLimit.LimitEntry{
      ...>   routing_val: "na1",
      ...>   endpoint: nil,
      ...>   limit_type: :service,
      ...>   retry_after: 45
      ...> }
      iex> LolApi.RateLimit.KeyBuilder.build(:cooldown, service_entry)
      "lol_api:v1:cooldown:na1:service"

  """
  @spec build(key_type(), LimitEntry.t()) :: String.t()
  def build(type, %LimitEntry{} = entry) do
    {prefix, mode, suffix} = parts_by_type(type, entry)

    Enum.join(
      [
        prefix,
        @version,
        mode,
        entry.routing_val
      ] ++ suffix,
      @joiner
    )
  end

  defp parts_by_type(:live_counter, entry) do
    {@our_prefix, :live, [entry.endpoint, entry.limit_type, :window, entry.window_sec]}
  end

  defp parts_by_type(:authoritative_counter, entry) do
    {@riot_prefix, :authoritative, [entry.endpoint, entry.limit_type, :window, entry.window_sec]}
  end

  defp parts_by_type(:policy_limit, entry) do
    {@riot_prefix, :policy, [entry.endpoint, entry.limit_type, :window, entry.window_sec, :limit]}
  end

  defp parts_by_type(:policy_windows, entry) do
    {@riot_prefix, :policy, [entry.endpoint, entry.limit_type, :windows]}
  end

  defp parts_by_type(:cooldown, entry) do
    suffix =
      case entry.limit_type do
        :method ->
          [entry.endpoint, entry.limit_type]

        _ ->
          [entry.limit_type]
      end

    {@our_prefix, :cooldown, suffix}
  end

  @doc """
  Builds all `:policy_windows` keys for a given `{routing_val, endpoint}` pair.

  One key is created per limit type (`:application`, `:method`).

  ## Example

      iex> LolApi.RateLimit.KeyBuilder.build_policy_window_keys("na1", "/lol/summoner")
      [
        "riot:v1:policy:na1:/lol/summoner:method:windows",
        "riot:v1:policy:na1:/lol/summoner:application:windows"
      ]
  """
  @spec build_policy_window_keys(routing_val(), endpoint()) :: list(key)
  def build_policy_window_keys(routing_val, endpoint) do
    Enum.map(
      RateLimit.policy_limit_types(),
      &build(
        :policy_windows,
        LimitEntry.create!(%{routing_val: routing_val, endpoint: endpoint, limit_type: &1})
      )
    )
  end

  @doc """
  Builds a list of Redis cooldown keys for all known `limit_types`.

  This is used to check for active cooldowns on a given `{routing_val, endpoint}`.

  ## Example

      iex> LolApi.RateLimit.KeyBuilder.build_cooldown_keys("na1", "/lol/summoner")
      [
        "lol_api:v1:cooldown:na1:/lol/summoner:method",
        "lol_api:v1:cooldown:na1:service",
        "lol_api:v1:cooldown:na1:application"
      ]

  """
  @spec build_cooldown_keys(routing_val(), endpoint()) :: [String.t()]
  def build_cooldown_keys(routing_val, endpoint) do
    Enum.map(
      RateLimit.limit_types(),
      &build(
        :cooldown,
        LimitEntry.create!(%{routing_val: routing_val, endpoint: endpoint, limit_type: &1})
      )
    )
  end
end
