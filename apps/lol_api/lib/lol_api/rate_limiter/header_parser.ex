defmodule LolApi.RateLimiter.HeaderParser do
  @moduledoc """
  Parses Riot headers with rate limiting info into LimitEntry
  """
  alias LolApi.RateLimiter.LimitEntry
  alias LolApi.RateLimiter.LimitEntry

  require Logger

  @app_limit "x-app-rate-limit"
  @app_count "x-app-rate-limit-count"
  @method_limit "x-method-rate-limit"
  @method_count "x-method-rate-limit-count"
  @date "date"
  @retry_after "retry-after"

  @header_vars %{
    app_limit: @app_limit
  }

  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type limit_type :: :app | :method
  @type headers :: [{String.t(), String.t()}]

  @doc """
  Parse rate limit headers from Riot to limit entries.

  ## Examples

      iex> headers = [
      ...>   {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
      ...>   {"x-app-rate-limit", "100:120,20:1"},
      ...>   {"x-app-rate-limit-count", "20:120,2:1"},
      ...>   {"x-method-rate-limit", "50:10"},
      ...>   {"x-method-rate-limit-count", "20:10"}
      ...> ]
      iex> result = LolApi.RateLimiter.HeaderParser.parse(headers)
      iex> Enum.sort_by(result, &{&1.limit_type, &1.window_sec})
      [
        %LolApi.RateLimiter.LimitEntry{
          limit_type: :app,
          window_sec: 1,
          count_limit: 20,
          count: 2,
          request_time: ~U[2025-04-01 18:15:26Z],
          endpoint: nil,
          retry_after: nil,
          routing_val: nil
        },
        %LolApi.RateLimiter.LimitEntry{
          limit_type: :app,
          window_sec: 120,
          count_limit: 100,
          count: 20,
          request_time: ~U[2025-04-01 18:15:26Z],
          endpoint: nil,
          retry_after: nil,
          routing_val: nil
        },
        %LolApi.RateLimiter.LimitEntry{
          limit_type: :method,
          window_sec: 10,
          count_limit: 50,
          count: 20,
          request_time: ~U[2025-04-01 18:15:26Z],
          endpoint: nil,
          retry_after: nil,
          routing_val: nil
        }
      ]
  """
  @spec parse(headers) :: [LimitEntry.t()]
  def parse(headers) do
    map = Enum.into(headers, %{})
    request_time = map[@date]
    retry_after = map[@retry_after]

    parse_limits(map[@app_limit], map[@app_count], :app, request_time, retry_after) ++
      parse_limits(map[@method_limit], map[@method_count], :method, request_time, retry_after)
  end

  # limit header is missing but count header is present
  defp parse_limits(nil = _limit_str, _count_str, _, _, _) do
    Logger.warning(
      "Riot's #{@app_limit} or #{@method_limit} header is missing. Can't derive window and quota."
    )

    []
  end

  # count header is missing, limit is present
  defp parse_limits(limit_str, nil = _count_str, type, request_time, retry_after) do
    Logger.debug(
      "Riot's #{@app_count} or #{@method_count} header is missing. Assuming it has value 0."
    )

    limit_by_window = limit_str |> String.split(",") |> Map.new(&parse_entry/1)

    for {window_sec, count_limit} <- limit_by_window do
      %{
        count: 0,
        count_limit: count_limit,
        limit_type: type,
        request_time: request_time,
        window_sec: window_sec,
        retry_after: retry_after
      }
      |> LimitEntry.create!()
    end
  end

  # both headers are missing
  defp parse_limits(nil, nil, _, _, _) do
    Logger.debug("Both Riot's rate limiter headers are missing")
    []
  end

  defp parse_limits(limit_str, count_str, type, request_time, retry_after) do
    limit_by_window = limit_str |> String.split(",") |> Map.new(&parse_entry/1)
    count_by_window = count_str |> String.split(",") |> Map.new(&parse_entry/1)

    for {window_sec, count_limit} <- limit_by_window do
      %{
        count: Map.get(count_by_window, window_sec),
        count_limit: count_limit,
        limit_type: type,
        request_time: request_time,
        window_sec: window_sec,
        retry_after: retry_after
      }
      |> LimitEntry.create!()
    end
  end

  defp parse_entry(entry) do
    [v, k] = String.split(entry, ":")
    {k, v}
  end
end
