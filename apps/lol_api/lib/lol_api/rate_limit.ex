defmodule LolApi.RateLimit do
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

  alias LolApi.Config
  alias LolApi.RateLimit.LimitEntry
  alias LolApi.RateLimit.{Cooldown, HeaderParser, Policy}

  require Logger

  @limit_types [:method, :service, :application]
  @policy_limit_types [:method, :application]

  @type limit_type :: :method | :service | :application
  @type policy_limit_type :: :method | :application

  @type routing_val :: String.t()
  @type endpoint :: String.t()

  @type limit_entry :: LimitEntry.t()
  @type limit_entries :: [limit_entry()]

  @type allow :: {:allow, limit_entries()}
  @type throttle :: {:throttle, limit_entries()}

  @type headers :: [{String.t(), String.t()}]

  @type opts :: Keyword.t()

  @spec limit_types :: [limit_type()]
  def limit_types, do: @limit_types

  @spec policy_limit_types :: [policy_limit_type()]
  def policy_limit_types, do: @policy_limit_types

  @spec hit(routing_val(), endpoint(), opts()) :: allow | throttle | {:error, ErrorMessage.t()}
  def hit(routing_val, endpoint, opts \\ []) do
    pool_name = Keyword.get(opts, :pool_name, Config.pool_name())

    with {:allow, _limit_entries} <- Cooldown.status(routing_val, endpoint, pool_name: pool_name),
         {:ok, true} <- Policy.known?(routing_val, endpoint, pool_name: pool_name),
         {:ok, limit_entries} <- Policy.fetch(routing_val, endpoint, pool_name: pool_name),
         {:allow, policy_entries} <-
           Policy.enforce_and_maybe_incr_counter(limit_entries, pool_name: pool_name) do
      Logger.debug("Request allowed. Details: #{inspect(policy_entries, pretty: true)}")
      {:allow, policy_entries}
    else
      {:ok, false} ->
        limit_entry =
          LimitEntry.create!(%{routing_val: routing_val, endpoint: endpoint, source: :policy})

        Logger.debug(
          "Policy unknown, making a blind request. Details: #{inspect(limit_entry, pretty: true)}"
        )

        {:allow, [limit_entry]}

      {:throttle, limit_entries} = throttle ->
        Logger.debug("Request throttled. Details: #{inspect(limit_entries, pretty: true)}")
        throttle

      {:error, _} = err ->
        err
    end
  end

  @spec refresh(headers(), routing_val(), endpoint(), opts()) ::
          {:ok, limit_entries()} | {:error, ErrorMessage.t()}
  def refresh(headers, routing_val, endpoint, opts \\ []) do
    pool_name = Keyword.get(opts, :pool_name, Config.pool_name())
    now = Keyword.get(opts, :now, DateTime.utc_now(:second))

    with :ok <-
           Cooldown.maybe_set(headers, routing_val, endpoint, pool_name: pool_name, now: now),
         {:ok, false} <- Policy.known?(routing_val, endpoint, pool_name: pool_name),
         :ok <- Policy.set(headers, routing_val, endpoint, pool_name: pool_name),
         limit_entries <- HeaderParser.parse(headers, routing_val, endpoint) do
      {:ok, limit_entries}
    end
  end
end
