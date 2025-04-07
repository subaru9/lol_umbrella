defmodule LolApi.Config do
  def api_key!(), do: Application.fetch_env!(:lol_api, :api_key)

  def rate_limiter_redis_pool_opts do
    :lol_api
    |> Application.fetch_env!(:rate_limiter)
    |> Keyword.fetch!(:redis_pool)
  end
end
