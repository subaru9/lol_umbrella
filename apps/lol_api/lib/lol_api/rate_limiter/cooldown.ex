defmodule LolApi.RateLimiter.Cooldown do
  @moduledoc """
  Responsible for setting and enforcing cooldown policy
  """
  require Logger

  alias LolApi.Config
  alias LolApi.RateLimiter
  alias LolApi.RateLimiter.{HeaderParser, KeyBuilder, RedisCommand, TTL}
  alias SharedUtils.Redis

  @type routing_val :: RateLimiter.routing_val()
  @type endpoint :: RateLimiter.endpoint()
  @type headers :: HeaderParser.headers()

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
      iex> LolApi.RateLimiter.Cooldown.build_key("na1", "/lol/summoner", headers)
      "lol_api:v1:cooldown:na1:/lol/summoner:application:120"
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
  Checks whether a cooldown key exists in Redis for a given `{routing_val, endpoint, limit_type}` triple.

  Used to immediately reject requests if a cooldown is active.

  ## Example

      iex> Cooldown.exists?("na1", "/lol/summoner", :application)
      true
  """

  # @spec exists?(routing_val(), endpoint(), limit_type()) :: boolean()

  @doc """
  Sets a cooldown key in Redis if headers indicate cooldown is required.

  This function builds a cooldown key from the headers and writes it into Redis
  with a TTL calculated based on `request_time` and `retry_after`.

  Raises if the TTL is non-positive.
  """
  @spec maybe_set(HeaderParser.headers(), routing_val(), endpoint()) :: :ok
  def maybe_set(headers, routing_val, endpoint) do
    with true <- create?(headers),
         limit_entry <- HeaderParser.extract_cooldown(headers, routing_val, endpoint),
         ttl <- TTL.adjust!(limit_entry),
         key <- KeyBuilder.build(:cooldown, limit_entry) do
      key
      |> RedisCommand.build_cooldown_setex_command(ttl)
      |> Redis.with_pool(Config.redis_pool_name(), fn
        "OK" ->
          Logger.debug("Set cooldown key #{key} with TTL #{ttl}")
          :ok
      end)
    else
      false ->
        Logger.debug("Cooldown skipped: headers do not contain retry-after or rate-limit-type")
        :ok
    end
  end
end
