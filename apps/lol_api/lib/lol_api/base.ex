defmodule LolApi.Base do
  @regions ~w(
    americas
    asia
    europe
    sea
  )

  @platforms ~w(
    br1
    eun1
    euw1
    jp1
    kr
    la1
    la2
    na1
    oc1
    tr1
    ru
    ph2
    sg2
    th2
    tw2
    vn2
  )
  alias SharedUtils.JSON

  def request(url) do
    if Mix.env() === :test do
      url
      |> HTTPSandbox.get_response([], [])
      |> handle_response(url)
    else
      :get
      |> Finch.build(url, req_headers())
      |> Finch.request(LolApiFinch)
      |> handle_response(url)
    end
  end

  def base_url(region), do: "https://#{region}.api.riotgames.com"

  defp handle_response(
         {:ok, %Finch.Response{status: status, body: body, headers: _resp_headers}},
         _url
       )
       when status in 200..299 do
    JSON.decode(body)
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}, url) do
    {:ok, %{"status" => %{"message" => message}}} = JSON.decode(body)
    code = ErrorMessage.http_code_reason_atom(status)

    {:error, apply(ErrorMessage, code, [message, %{endpoint: url}])}
  end

  defp handle_response({:error, %{__exception__: true} = exception}, url) do
    {:error,
     ErrorMessage.internal_server_error(
       Exception.message(exception),
       %{endpoint: url, exception: exception}
     )}
  end

  defp handle_response({:error, error}, url) do
    {:error, ErrorMessage.internal_server_error(inspect(error), %{endpoint: url})}
  end

  defp req_headers, do: [{"X-Riot-Token", Application.fetch_env!(:lol_api, :api_key)}]

  def paginate(url, request_fun, page \\ 1, acc \\ []) do
    paginated_url = "#{url}?page=#{page}"

    case request_fun.(paginated_url) do
      {:ok, []} ->
        {:ok, acc}

      {:ok, results} ->
        paginate(url, request_fun, page + 1, acc ++ results)

      {:error, error} ->
        {:error, error}
    end
  end

  defp regions, do: @regions
  defp platforms, do: @platforms
end
