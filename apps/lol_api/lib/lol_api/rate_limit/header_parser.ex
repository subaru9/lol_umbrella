defmodule LolApi.RateLimit.HeaderParser do
  @moduledoc """
  Parses Riot headers with rate limiting info into LimitEntry
  """
  alias LolApi.Config
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
  @type opts :: Keyword.t()

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
  based on Riot response headers.

  This function extracts the `x-rate-limit-type`, `retry-after`, and `date`
  headers to construct a cooldown limit entry. If `retry-after` or `date`
  are missing, defaults are applied. All other headers are ignored.

  Currently, exponential backoff is not implemented — the raw `retry-after` is used
  or capped by max configured cooldown.

  ## Examples

  Application rate limit:

    iex> headers = [
    ...>   {"retry-after", "5"},
    ...>   {"x-rate-limit-type", "application"},
    ...>   {"x-app-rate-limit", "20:10"},
    ...>   {"x-app-rate-limit-count", "21:10"},
    ...>   {"x-method-rate-limit", "100:20"},
    ...>   {"x-method-rate-limit-count", "1:20"},
    ...>   {"date", "Tue, 01 Apr 2025 18:15:26 GMT"}
    ...> ]
    iex> now = ~U[2025-04-01 18:15:30Z]
    iex> max_ttl = 900
    iex> LolApi.RateLimit.HeaderParser.extract_cooldown(headers, "na1", "/lol/spectator/v3/featured-games", now: now, max_ttl: max_ttl)
    %LolApi.RateLimit.LimitEntry{
      routing_val: :na1,
      endpoint: "/lol/spectator/v3/featured-games",
      limit_type: :application,
      retry_after: 5,
      request_time: ~U[2025-04-01 18:15:26Z],
      window_sec: nil,
      count_limit: nil,
      count: 0,
      source: :headers
    }

  Method rate limit:

    iex> headers = [
    ...>   {"retry-after", "7"},
    ...>   {"x-rate-limit-type", "method"},
    ...>   {"x-method-rate-limit", "100:20"},
    ...>   {"x-method-rate-limit-count", "105:20"},
    ...>   {"date", "Tue, 01 Apr 2025 18:00:00 GMT"}
    ...> ]
    iex> now = ~U[2025-04-01 18:00:01Z]
    iex> max_ttl = 900
    iex> LolApi.RateLimit.HeaderParser.extract_cooldown(headers, "la1", "/lol/spectator/v3/featured-games", now: now, max_ttl: max_ttl)
    %LolApi.RateLimit.LimitEntry{
      routing_val: :la1,
      endpoint: "/lol/spectator/v3/featured-games",
      limit_type: :method,
      retry_after: 7,
      request_time: ~U[2025-04-01 18:00:00Z],
      window_sec: nil,
      count_limit: nil,
      count: 0,
      source: :headers
    }

  Service rate limit fallback (no `retry-after`, uses `max_ttl`):

    iex> headers = [
    ...>   {"x-app-rate-limit", "20:10"},
    ...>   {"x-app-rate-limit-count", "1:10"},
    ...>   {"x-method-rate-limit", "100:20"},
    ...>   {"x-method-rate-limit-count", "5:20"},
    ...>   {"date", "Tue, 01 Apr 2025 18:16:00 GMT"}
    ...> ]
    iex> now = ~U[2025-04-01 18:16:05Z]
    iex> max_ttl = 900
    iex> LolApi.RateLimit.HeaderParser.extract_cooldown(headers, "na1", "/lol/spectator/v3/featured-games", now: now, max_ttl: max_ttl)
    %LolApi.RateLimit.LimitEntry{
      routing_val: :na1,
      endpoint: "/lol/spectator/v3/featured-games",
      limit_type: :service,
      retry_after: 900,
      request_time: ~U[2025-04-01 18:16:00Z],
      window_sec: nil,
      count_limit: nil,
      count: 0,
      source: :headers
    }
  """
  @spec extract_cooldown(headers(), routing_val(), endpoint(), opts()) :: limit_entry()
  def extract_cooldown(resp_headers, routing_val, endpoint, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now(:second))
    max_ttl = Keyword.get(opts, :max_ttl, Config.max_cooldown_ttl())

    headers = Enum.into(resp_headers, %{})

    arg = %{
      limit_type: Map.get(headers, @limit_type, :service),
      request_time: Map.get(headers, @date, now),
      retry_after: Map.get(headers, @retry_after, max_ttl),
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
    iex> result = LolApi.RateLimit.HeaderParser.parse(headers, "euw1", "/lol/summoner")
    iex> Enum.sort_by(result, &{&1.limit_type, &1.window_sec})
    [
      %LolApi.RateLimit.LimitEntry{
        limit_type: :application,
        window_sec: 1,
        count_limit: 20,
        count: 2,
        request_time: ~U[2025-04-01 18:15:26Z],
        endpoint: "/lol/summoner",
        source: :headers,
        retry_after: nil,
        routing_val: :euw1
      },
      %LolApi.RateLimit.LimitEntry{
        limit_type: :application,
        window_sec: 120,
        count_limit: 100,
        count: 20,
        request_time: ~U[2025-04-01 18:15:26Z],
        endpoint: "/lol/summoner",
        source: :headers,
        retry_after: nil,
        routing_val: :euw1
      },
      %LolApi.RateLimit.LimitEntry{
        limit_type: :method,
        window_sec: 10,
        count_limit: 50,
        count: 20,
        request_time: ~U[2025-04-01 18:15:26Z],
        endpoint: "/lol/summoner",
        source: :headers,
        retry_after: nil,
        routing_val: :euw1
      }
    ]
  """
  @spec parse(headers(), routing_val(), endpoint()) ::
          limit_entries() | {:error, ErrorMessage.t()}
  def parse(headers, routing_val, endpoint) do
    map = Enum.into(headers, %{})
    request_time = map[@date]
    retry_after = map[@retry_after]

    parse_limits(
      map[@app_limit],
      map[@app_count],
      :application,
      request_time,
      retry_after,
      routing_val,
      endpoint
    ) ++
      parse_limits(
        map[@method_limit],
        map[@method_count],
        :method,
        request_time,
        retry_after,
        routing_val,
        endpoint
      )
  end

  # cover both headers missing, or just limit header is missing but count header is present
  defp parse_limits(
         limit_str,
         count_str,
         limit_type,
         request_time,
         retry_after,
         routing_val,
         endpoint
       )
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
       retry_after: retry_after,
       routing_val: routing_val,
       endpoint: endpoint
     })}
  end

  # count header is missing, limit is present
  defp parse_limits(
         limit_str,
         nil = _count_str,
         type,
         request_time,
         retry_after,
         routing_val,
         endpoint
       ) do
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
        routing_val: routing_val,
        endpoint: endpoint,
        source: :headers
      }
      |> LimitEntry.create!()
    end
  end

  defp parse_limits(limit_str, count_str, type, request_time, retry_after, routing_val, endpoint) do
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
        routing_val: routing_val,
        endpoint: endpoint,
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
