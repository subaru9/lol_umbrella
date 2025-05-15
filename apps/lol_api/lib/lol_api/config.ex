defmodule LolApi.Config do
  @moduledoc false

  @app :lol_api

  def api_key!, do: Application.fetch_env!(:lol_api, :api_key)
  def current_env, do: Application.fetch_env!(@app, :env)

  def pool_opts do
    @app
    |> Application.fetch_env!(:rate_limiter)
    |> Keyword.fetch!(:pool)
  end

  def pool_name do
    Map.fetch!(pool_opts(), :pool_name)
  end

  def worker_opts do
    @app
    |> Application.fetch_env!(:rate_limiter)
    |> Keyword.fetch!(:pool_worker)
  end
end
