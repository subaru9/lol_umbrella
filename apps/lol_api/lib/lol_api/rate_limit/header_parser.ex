defmodule LolApi.RateLimit.HeaderParser do
  @moduledoc """
  Parses Riot headers with rate limiting info into LimitEntry
  """
  alias LolApi.RateLimit
  alias LolApi.RateLimit.LimitEntry

  require Logger

  @limit_type "x-rate-limit-type"
  @app_limit "x-app-rate-limit"
  @app_count "x-app-rate-limit-count"
  @method_limit "x-method-rate-limit"
  @method_count "x-method-rate-limit-count"
  @date "date"
  @retry_after "retry-after"

  @type headers :: [{String.t(), String.t()}]

  @type routing_val :: RateLimit.routing_val()
  @type endpoint :: RateLimit.endpoint()

  @type limit_entry :: LimitEntry.t()
  @type limit_entries :: [limit_entry()]

  @type header_name :: String.t()

  @spec header_name!(atom()) :: header_name()
  def header_name!(nickname) do
    case nickname do
      :limit_type ->
        @limit_type

      :retry_after ->
        @retry_after

      :request_time ->
        @date

      _ ->
        raise("Unknown header.")
    end
  end

  @doc """
  Builds a minimal `%LimitEntry{}` representing a cooldown
  based on the Riot response headers.

  ## Examples

      iex> headers = [
      ...>   {"x-rate-limit-type", "application"},
      ...>   {"retry-after", "42"},
      ...>   {"date", "Tue, 01 Apr 2025 18:15:26 GMT"}
      ...> ]
      iex> LolApi.RateLimit.HeaderParser.extract_cooldown(headers, "na1", "/lol/summoner")
      %LolApi.RateLimit.LimitEntry{
        routing_val: :na1,
        endpoint: "/lol/summoner",
        limit_type: :application,
        retry_after: 42,
        request_time: ~U[2025-04-01 18:15:26Z],
        window_sec: nil,
        count_limit: nil,
        count: 0,
        source: :headers
      }
  """
  @spec extract_cooldown(headers(), routing_val(), endpoint()) :: limit_entry()
  def extract_cooldown(resp_headers, routing_val, endpoint) do
    headers = Enum.into(resp_headers, %{})

    arg = %{
      limit_type: headers[@limit_type],
      request_time: headers[@date],
      retry_after: headers[@retry_after],
      endpoint: endpoint,
      routing_val: routing_val,
      source: :headers
    }

    LimitEntry.create!(arg)
  end

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
      iex> result = LolApi.RateLimit.HeaderParser.parse(headers)
      iex> Enum.sort_by(result, &{&1.limit_type, &1.window_sec})
      [
        %LolApi.RateLimit.LimitEntry{
          limit_type: :application,
          window_sec: 1,
          count_limit: 20,
          count: 2,
          request_time: ~U[2025-04-01 18:15:26Z],
          endpoint: nil,
          source: :headers,
          retry_after: nil,
          routing_val: nil
        },
        %LolApi.RateLimit.LimitEntry{
          limit_type: :application,
          window_sec: 120,
          count_limit: 100,
          count: 20,
          request_time: ~U[2025-04-01 18:15:26Z],
          endpoint: nil,
          source: :headers,
          retry_after: nil,
          routing_val: nil
        },
        %LolApi.RateLimit.LimitEntry{
          limit_type: :method,
          window_sec: 10,
          count_limit: 50,
          count: 20,
          request_time: ~U[2025-04-01 18:15:26Z],
          endpoint: nil,
          source: :headers,
          retry_after: nil,
          routing_val: nil
        }
      ]
  """
  @spec parse(headers) :: limit_entries() | {:error, ErrorMessage.t()}
  def parse(headers) do
    map = Enum.into(headers, %{})
    request_time = map[@date]
    retry_after = map[@retry_after]

    parse_limits(map[@app_limit], map[@app_count], :application, request_time, retry_after) ++
      parse_limits(map[@method_limit], map[@method_count], :method, request_time, retry_after)
  end

  @spec parse(headers(), routing_val(), endpoint()) :: limit_entries()
  def parse(headers, routing_val, endpoint) do
    headers
    |> parse()
    |> Enum.map(
      &LimitEntry.update!(&1, %{
        routing_val: routing_val,
        endpoint: endpoint,
        source: :headers
      })
    )
  end

  # cover both headers missing, or just limit header is missing but count header is present
  defp parse_limits(limit_str, count_str, limit_type, request_time, retry_after)
       when (is_nil(limit_str) and is_nil(count_str)) or is_nil(limit_str) do
    warning =
      "[LolApi.RateLimit.HeaderParser] header is missing. Can't derive window_sec and count_limit."

    Logger.warning(warning)

    {:error,
     ErrorMessage.internal_server_error(warning, %{
       limit_str: limit_str,
       count_str: count_str,
       limit_type: limit_type,
       request_time: request_time,
       retry_after: retry_after
     })}
  end

  # count header is missing, limit is present
  defp parse_limits(limit_str, nil = _count_str, type, request_time, retry_after) do
    Logger.warning(
      "[LolApi.RateLimit.HeaderParser] Riot's #{@app_count} or #{@method_count} header is missing. Assuming it has value 0."
    )

    limit_by_window = limit_str |> String.split(",") |> Map.new(&parse_entry/1)

    for {window_sec, count_limit} <- limit_by_window do
      %{
        count: 0,
        count_limit: count_limit,
        limit_type: type,
        request_time: request_time,
        window_sec: window_sec,
        retry_after: retry_after,
        source: :headers
      }
      |> LimitEntry.create!()
    end
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
        retry_after: retry_after,
        source: :headers
      }
      |> LimitEntry.create!()
    end
  end

  defp parse_entry(entry) do
    [v, k] = String.split(entry, ":")
    {k, v}
  end
end
