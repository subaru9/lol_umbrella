defmodule LolApi.RateLimiter.KeyParser do
  @moduledoc """
  Parses structured Redis rate-limiting keys into maps for telemetry.
  """
  alias LolApi.RateLimiter.LimitEntry

  @type redis_key :: String.t()

  @doc """
  Parses a structured Redis key into a `%LimitEntry{}`.

  Infers source from the key prefix and mode (e.g. `:policy`, `:cooldown`).

  ## Examples

      iex> LolApi.RateLimiter.KeyParser.parse("riot:v1:policy:euw1:/lol/match:application:window:120:limit")
      %LolApi.RateLimiter.LimitEntry{
        routing_val: :euw1,
        endpoint: "/lol/match",
        limit_type: :application,
        window_sec: 120,
        source: :policy
      }

      iex> LolApi.RateLimiter.KeyParser.parse("riot:v1:policy:euw1:/lol/match:application:windows")
      %LolApi.RateLimiter.LimitEntry{
        routing_val: :euw1,
        endpoint: "/lol/match",
        limit_type: :application,
        source: :policy
      }

      iex> LolApi.RateLimiter.KeyParser.parse("lol_api:v1:cooldown:na1:application")
      %LolApi.RateLimiter.LimitEntry{
        routing_val: :na1,
        limit_type: :application,
        source: :cooldown
      }

      iex> LolApi.RateLimiter.KeyParser.parse("lol_api:v1:cooldown:na1:service")
      %LolApi.RateLimiter.LimitEntry{
        routing_val: :na1,
        limit_type: :service,
        source: :cooldown
      }

      iex> LolApi.RateLimiter.KeyParser.parse("lol_api:v1:cooldown:na1:/lol/summoner:method")
      %LolApi.RateLimiter.LimitEntry{
        routing_val: :na1,
        endpoint: "/lol/summoner",
        limit_type: :method,
        source: :cooldown
      }
  """
  @spec parse(redis_key()) :: LimitEntry.t()
  def parse(key), do: key |> String.split(":") |> parse_parts()

  defp parse_parts([
         prefix,
         version,
         source,
         routing_val,
         endpoint,
         limit_type,
         "window",
         window_sec | _suffix
       ]) do
    LimitEntry.create!(%{
      prefix: prefix,
      version: version,
      source: source,
      routing_val: routing_val,
      endpoint: endpoint,
      limit_type: limit_type,
      window_sec: window_sec
    })
  end

  defp parse_parts([
         prefix,
         version,
         source,
         routing_val,
         endpoint,
         limit_type | suffix
       ]) do
    LimitEntry.create!(%{
      prefix: prefix,
      version: version,
      source: source,
      routing_val: routing_val,
      endpoint: endpoint,
      limit_type: limit_type,
      suffix: suffix
    })
  end

  defp parse_parts([
         prefix,
         version,
         "cooldown",
         routing_val,
         limit_type
       ]) do
    LimitEntry.create!(%{
      prefix: prefix,
      version: version,
      source: :cooldown,
      routing_val: routing_val,
      limit_type: limit_type
    })
  end

  defp parse_parts([
         prefix,
         version,
         "cooldown",
         routing_val,
         endpoint,
         "method"
       ]) do
    LimitEntry.create!(%{
      prefix: prefix,
      version: version,
      source: :cooldown,
      routing_val: routing_val,
      endpoint: endpoint,
      limit_type: :method
    })
  end

  defp parse_parts(parts) do
    raise "[LolApi.RateLimiter.KeyParser] Unmached key parts: #{inspect(parts)}"
  end
end
