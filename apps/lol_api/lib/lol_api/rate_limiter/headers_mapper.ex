defmodule LolApi.RateLimiter.HeadersMapper do
  require Logger

  @app_limit "x-app-rate-limit"
  @app_count "x-app-rate-limit-count"
  @method_limit "x-method-rate-limit"
  @method_count "x-method-rate-limit-count"
  @date "date"
  @retry_after "retry-after"

  @type routing_val :: String.t()
  @type endpoint :: String.t()
  @type limit_type :: :app | :method
  @type headers :: [{String.t(), String.t()}]
  @type entry :: %{
          required(:limit_type) => limit_type(),
          required(:window_sec) => pos_integer(),
          required(:count_limit) => pos_integer(),
          required(:count) => non_neg_integer(),
          required(:request_time) => String.t(),
          optional(:retry_after) => pos_integer()
        }

  @doc """
  Maps rate limit headers from a Riot to header entries

  ## Examples

      iex> headers = [
      ...>   {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
      ...>   {"x-app-rate-limit", "100:120,20:1"},
      ...>   {"x-app-rate-limit-count", "20:120,2:1"},
      ...>   {"x-method-rate-limit", "50:10"},
      ...>   {"x-method-rate-limit-count", "20:10"}
      ...> ]
      iex> LolApi.RateLimiter.HeadersMapper.parse(headers)
      [
        %{
          limit_type: :app,
          window_sec: 120,
          count_limit: 100,
          count: 20,
          request_time: ~U[2025-04-01 18:15:26Z]
        },
        %{
          limit_type: :app,
          window_sec: 1,
          count_limit: 20,
          count: 2,
          request_time: ~U[2025-04-01 18:15:26Z]
        },
        %{
          limit_type: :method,
          window_sec: 10,
          count_limit: 50,
          count: 20,
          request_time: ~U[2025-04-01 18:15:26Z]
        }
      ]
  """
  @spec parse(headers) :: [entry]
  def parse(headers) do
    map = Enum.into(headers, %{})
    request_time = parse_request_time_header(map)
    retry_after = map[@retry_after]

    parse_limits(map[@app_limit], map[@app_count], :app, request_time, retry_after) ++
      parse_limits(map[@method_limit], map[@method_count], :method, request_time, retry_after)
  end

  # partially missing
  defp parse_limits(nil, _count, _, _, _) do
    Logger.debug("Riot's #{@app_limit} or #{@method_limit} header is missing")
    []
  end

  defp parse_limits(_limit, nil, _, _, _) do
    Logger.debug("Riot's #{@app_count} or #{@method_count} header is missing")
    []
  end

  # both headers are missing
  defp parse_limits(nil, nil, _, _, _) do
    Logger.debug("Both Riot's rate limiter headers are missing")
    []
  end

  defp parse_limits(limit_str, count_str, type, request_time, retry_after) do
    limit_by_window = limit_str |> String.split(",") |> Map.new(&parse_entry/1)
    count_by_window = count_str |> String.split(",") |> Map.new(&parse_entry/1)

    entries =
      for {window_sec, count_limit} <- limit_by_window do
        %{
          count: Map.get(count_by_window, window_sec, 0),
          count_limit: count_limit,
          limit_type: type,
          request_time: request_time,
          window_sec: window_sec
        }
      end

    if retry_after,
      do: Enum.map(entries, &Map.put(&1, :retry_after_sec, String.to_integer(retry_after))),
      else: entries
  end

  defp parse_entry(entry) do
    [v, k] = String.split(entry, ":")
    {String.to_integer(k), String.to_integer(v)}
  end

  defp parse_request_time_header(header_map) do
    with value when is_binary(value) <- header_map[@date],
         {:ok, dt} <- Timex.parse(value, "{RFC1123}") do
      dt
    else
      _ -> DateTime.utc_now()
    end
  end

  @doc """
  Groups a flat list of parsed header entries by `{routing_val, endpoint, limit_type}`.

  This prepares the data for batching into Redis, so all windows and limits are stored together per policy type.

  ## Example

      iex> parsed_headers = [
      ...>   %{limit_type: :app, window_sec: 120, count_limit: 100},
      ...>   %{limit_type: :app, window_sec: 1, count_limit: 20},
      ...>   %{limit_type: :method, window_sec: 10, count_limit: 50}
      ...> ]
      iex> LolApi.RateLimiter.RedisCommand.group_by_routing_endpoint_and_type(parsed_headers, "na1", "/lol/summoner")
      %{
        {"na1", "/lol/summoner", :app} => [
          %{limit_type: :app, window_sec: 120, count_limit: 100},
          %{limit_type: :app, window_sec: 1, count_limit: 20}
        ],
        {"na1", "/lol/summoner", :method} => [
          %{limit_type: :method, window_sec: 10, count_limit: 50}
        ]
      }

  """
  @spec group_by_routing_endpoint_and_type([entry], routing_val(), endpoint()) ::
          %{
            {String.t(), String.t(), atom()} => [map()]
          }
  def group_by_routing_endpoint_and_type(header_entries, routing_val, endpoint) do
    Enum.group_by(header_entries, fn %{limit_type: type} ->
      {routing_val, endpoint, type}
    end)
  end
end
