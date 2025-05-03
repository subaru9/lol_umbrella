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

  alias LolApi.RateLimiter.{Cooldown, HeaderParser, Policy}

  @limit_types [:method, :service, :application]
  @policy_limit_types [:method, :application]

  @type limit_type :: :method | :service | :application
  @type policy_limit_type :: :method | :application

  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type headers :: HeaderParser.headers()
  @type allowed :: {:ok, :allowed}
  @type throttled :: {:error, :throttled, pos_integer()}

  @spec limit_types :: [limit_type()]
  def limit_types, do: @limit_types

  @spec policy_limit_types :: [policy_limit_type()]
  def policy_limit_types, do: @policy_limit_types

  @spec hit(routing_val, endpoint, headers) ::
          allowed | throttled | {:error, ErrorMessage.t()}
  def hit(routing_val, endpoint, headers) do
    case Policy.known?(routing_val, endpoint) do
      {:ok, true} ->
        limit_entries = Policy.get(routing_val, endpoint)
        Policy.enforce(limit_entries)

      {:ok, false} ->
        :ok = Policy.set(headers)
        Cooldown.maybe_set(headers, routing_val, endpoint)

        {:ok, :allowed}

      {:error, _} = err ->
        err
    end
  end
end
