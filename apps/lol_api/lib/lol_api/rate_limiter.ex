defmodule LolApi.RateLimiter do
  @moduledoc """
  Central definition of rate-limiting scope types.

  Riot API exposes three types of rate limits, listed here in order of ascending globality:

    • `:method` — narrowest; applies to a specific API method (e.g., `/lol/spectator/v3/featured-games`)
    • `:service` — mid-level; applies to an entire API service (e.g., Spectator-V3)
    • `:application` — broadest; applies globally across all endpoints under a given API key and region

  The limiter uses these types to structure both counters and cooldowns.

  Only `:method` and `:application` are used for **counters**, as Redis policies are defined for them explicitly.
  All three types may be used for **cooldowns**, depending on what `X-Rate-Limit-Type` is returned in a 429 response.
  """

  @limit_types [:method, :service, :application]
  @counter_limit_types [:method, :application]

  @type limit_type :: :method | :service | :application
  @type counter_limit_type :: :method | :application

  @type routing_val :: String.t()
  @type endpoint :: String.t()

  @spec limit_types :: [limit_type()]
  def limit_types, do: @limit_types

  @spec counter_limit_types :: [counter_limit_type()]
  def counter_limit_types, do: @counter_limit_types
end
