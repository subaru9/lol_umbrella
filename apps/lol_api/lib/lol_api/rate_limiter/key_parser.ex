defmodule LolApi.RateLimiter.KeyParser do
  @moduledoc """
  Parses structured Redis rate-limiting keys into maps for telemetry.
  """

  @type redis_key :: String.t()
  @type parsed_map :: %{
          required(:prefix) => String.t(),
          required(:version) => String.t(),
          required(:mode) => atom(),
          required(:routing_val) => String.t(),
          required(:endpoint) => String.t(),
          required(:limit_type) => atom(),
          optional(:window_sec) => pos_integer(),
          required(:suffix) => list(atom())
        }

  @doc """
  Parses a structured Redis rate-limiting key into a map.

  ## Examples

      iex> LolApi.RateLimiter.KeyParser.parse("riot:v1:policy:euw1:/lol/match:application:window:120:limit")
      %{
        prefix: "riot",
        version: "v1",
        mode: :policy,
        routing_val: "euw1",
        endpoint: "/lol/match",
        limit_type: :application,
        window_sec: 120,
        suffix: [:limit]
      }

      iex> LolApi.RateLimiter.KeyParser.parse("riot:v1:policy:euw1:/lol/match:application:windows")
      %{
        prefix: "riot",
        version: "v1",
        mode: :policy,
        routing_val: "euw1",
        endpoint: "/lol/match",
        limit_type: :application,
        suffix: [:windows]
      }
  """
  @spec parse(redis_key()) :: parsed_map()
  def parse(key), do: key |> String.split(":") |> parse_parts()

  defp parse_parts([
         prefix,
         version,
         mode,
         routing_val,
         endpoint,
         limit_type,
         "window",
         window_sec | suffix
       ]) do
    %{
      prefix: prefix,
      version: version,
      mode: String.to_atom(mode),
      routing_val: routing_val,
      endpoint: endpoint,
      limit_type: String.to_atom(limit_type),
      window_sec: String.to_integer(window_sec),
      suffix: Enum.map(suffix, &String.to_atom/1)
    }
  end

  defp parse_parts([
         prefix,
         version,
         mode,
         routing_val,
         endpoint,
         limit_type | suffix
       ]) do
    %{
      prefix: prefix,
      version: version,
      mode: String.to_atom(mode),
      routing_val: routing_val,
      endpoint: endpoint,
      limit_type: String.to_atom(limit_type),
      suffix: Enum.map(suffix, &String.to_atom/1)
    }
  end
end
