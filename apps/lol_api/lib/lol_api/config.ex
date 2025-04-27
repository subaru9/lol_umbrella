defmodule LolApi.Config do
  @moduledoc false

  @app :lol_api

  def api_key!, do: Application.fetch_env!(:lol_api, :api_key)
  def current_env, do: Application.fetch_env!(@app, :env)

  def rate_limiter_redis_pool_opts do
    @app
    |> Application.fetch_env!(:rate_limiter)
    |> Keyword.fetch!(:redis_pool)
  end

  def redis_pool_name do
    Map.fetch!(rate_limiter_redis_pool_opts(), :pool_name)
  end
end
