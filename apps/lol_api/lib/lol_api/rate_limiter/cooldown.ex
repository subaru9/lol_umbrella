defmodule LolApi.RateLimiter.Cooldown do
  @moduledoc """
  Responsible for setting and enforcing cooldown policy
  """
  require Logger

  alias LolApi.Config

  alias LolApi.RateLimiter.{
    HeaderParser,
    KeyBuilder,
    KeyValueParser,
    LimitEntry,
    RedisCommand,
    TTL
  }

  alias SharedUtils.Redis

  @type routing_val :: String.t()
  @type endpoint :: String.t()

  @type headers :: [{String.t(), String.t()}]

  @type limit_entry :: LimitEntry.t()
  @type limit_entries :: [limit_entry()]

  @type allow :: {:allow, limit_entries()}
  @type throttle :: {:throttle, limit_entries()}

  @doc """
  Builds a cooldown Redis key from the given `routing_val`, `endpoint`, and Riot response headers.

  The cooldown key structure is:

      "lol_api:v1:cooldown:<routing_val>:<endpoint>:<limit_type>:<retry_after>"

  ## Example

      iex> headers = [
      ...>   {"x-rate-limit-type", "application"},
      ...>   {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
      ...>   {"retry-after", "120"}
      ...> ]
      iex> LolApi.RateLimiter.Cooldown.build_key(headers, "na1", "/lol/summoner")
      "lol_api:v1:cooldown:na1:application"
  """
  def build_key(headers, routing_val, endpoint) do
    headers
    |> HeaderParser.extract_cooldown(routing_val, endpoint)
    |> then(&KeyBuilder.build(:cooldown, &1))
  end

  @doc """
  Checks if the response headers indicate that a cooldown should be created.

  Returns `true` if both `Retry-After` and `X-Rate-Limit-Type` headers are present.

  ## Examples

      iex> headers = [
      ...>   {"retry-after", "5"},
      ...>   {"x-rate-limit-type", "application"}
      ...> ]
      iex> LolApi.RateLimiter.Cooldown.create?(headers)
      true

      iex> headers = [
      ...>   {"retry-after", "5"}
      ...> ]
      iex> LolApi.RateLimiter.Cooldown.create?(headers)
      false

      iex> headers = [
      ...>   {"x-rate-limit-type", "method"}
      ...> ]
      iex> LolApi.RateLimiter.Cooldown.create?(headers)
      false

      iex> headers = []
      iex> LolApi.RateLimiter.Cooldown.create?(headers)
      false
  """
  @spec create?(HeaderParser.headers()) :: boolean()
  def create?(headers) do
    headers
    |> Enum.into(%{})
    |> then(
      &(Map.has_key?(&1, HeaderParser.retry_after_name()) and
          Map.has_key?(&1, HeaderParser.limit_type_name()))
    )
  end

  @doc """
  Sets a cooldown key in Redis if headers indicate cooldown is required.

  This function builds a cooldown key from the headers and writes it into Redis
  with a TTL calculated based on `request_time` and `retry_after`.

  Raises if the TTL is non-positive.
  """
  @spec maybe_set(HeaderParser.headers(), routing_val(), endpoint()) ::
          :ok | {:error, ErrorMessage.t()}
  def maybe_set(headers, routing_val, endpoint) do
    with true <- create?(headers),
         limit_entry <- HeaderParser.extract_cooldown(headers, routing_val, endpoint),
         ttl <- TTL.adjust!(limit_entry),
         key <- KeyBuilder.build(:cooldown, limit_entry) do
      key
      |> RedisCommand.build_cooldown_setex_command(ttl)
      |> Redis.with_pool(Config.redis_pool_name(), fn
        "OK" ->
          updated = LimitEntry.update!(limit_entry, %{adjusted_ttl: ttl})
          Logger.debug("[LolApi.RateLimiter.Cooldown] Coldown set. Details: #{inspect(updated)}")
          :ok
      end)
    else
      false ->
        limit_entry = HeaderParser.extract_cooldown(headers, routing_val, endpoint)

        Logger.debug(
          "[LolApi.RateLimiter.Cooldown] Cooldown skipped. Details: #{inspect(limit_entry)}"
        )

        :ok
    end
  end

  @doc """
  Checks if any cooldown is currently active for a given `routing_val` and `endpoint`.

  This function builds all cooldown key variants for known limit types (`:application`, `:method`, and `:service`), 
  then asks Redis which key has the longest active TTL. If any key is found with a positive TTL, 
  the request is rejected with `{:throttle, limit_entry}`. Otherwise, the request is considered allow.

  The returned `LimitEntry` helps trace which key caused throttling and how much time remains.

  This status ensures we honor cooldown periods imposed by Riot’s `Retry-After` header.

      iex> Cooldown.status("na1", "/lol/summoner")
      {:allow, %LimitEntry{...}}

      iex> Cooldown.status("na1", "/lol/spectator/v3/featured-games")
      {:throttle, %LimitEntry{ttl: 17, source: :cooldown, ...}}

  """
  @spec status(routing_val(), endpoint()) :: allow | throttle | {:error, ErrorMessage.t()}
  def status(routing_val, endpoint) do
    KeyBuilder.build_cooldown_keys(routing_val, endpoint)
    |> RedisCommand.get_cooldown_key_with_largest_ttl()
    |> Redis.with_pool(Config.redis_pool_name(), fn
      [] ->
        limit_entry =
          LimitEntry.create!(%{routing_val: routing_val, endpoint: endpoint, source: :cooldown})

        {:allow, [limit_entry]}

      [cooldown_key, ttl] ->
        limit_entry = KeyValueParser.parse_cooldown(cooldown_key, ttl)

        {:throttle, [limit_entry]}
    end)
  end
end
