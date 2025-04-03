defmodule LolApi.RateLimiter.HeadersParser do
  @moduledoc """
  Parses rate limit headers from a Riot Games-style HTTP response.

  ## Examples

      iex> headers = [
      ...>   {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
      ...>   {"x-app-rate-limit", "100:120,20:1"},
      ...>   {"x-app-rate-limit-count", "20:120,2:1"},
      ...>   {"x-method-rate-limit", "50:10"},
      ...>   {"x-method-rate-limit-count", "20:10"}
      ...> ]
      iex> LolApi.RateLimiter.HeadersParser.parse(headers)
      [
        %{limit_type: :app, window_sec: 120, count_limit: 100, count: 20,
          request_time: ~U[2025-04-01 18:15:26Z]},
        %{limit_type: :app, window_sec: 1, count_limit: 20, count: 2,
          request_time: ~U[2025-04-01 18:15:26Z]},
        %{limit_type: :method, window_sec: 10, count_limit: 50, count: 20,
          request_time: ~U[2025-04-01 18:15:26Z]}
      ]
  """

  @app_limit "x-app-rate-limit"
  @app_count "x-app-rate-limit-count"
  @method_limit "x-method-rate-limit"
  @method_count "x-method-rate-limit-count"
  @date "date"
  @retry_after "retry-after"

  @spec parse([{binary(), binary()}]) :: [map()]
  def parse(headers) do
    map = Enum.into(headers, %{})
    request_time = Timex.parse!(map[@date], "{RFC1123}")
    retry_after = map[@retry_after]

    parse_limits(map[@app_limit], map[@app_count], :app, request_time, retry_after) ++
      parse_limits(map[@method_limit], map[@method_count], :method, request_time, retry_after)
  end

  defp parse_limits(limit_str, count_str, type, request_time, retry_after) do
    limits = String.split(limit_str, ",")
    counts = String.split(count_str, ",")

    limits
    |> Enum.zip(counts)
    |> Enum.map(fn {limit_entry, count_entry} ->
      [count_limit, window_sec] = parse_entry(limit_entry)
      [count, ^window_sec] = parse_entry(count_entry)

      parsed = %{
        count: count,
        count_limit: count_limit,
        limit_type: type,
        request_time: request_time,
        window_sec: window_sec
      }

      if retry_after,
        do: Map.put(parsed, :retry_after_sec, String.to_integer(retry_after)),
        else: parsed
    end)
  end

  defp parse_entry(entry) do
    entry
    |> String.split(":")
    |> Enum.map(&String.to_integer/1)
  end
end
