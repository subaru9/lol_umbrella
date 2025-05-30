defmodule LolApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Lol API client
      {Finch, name: LolApiFinch},
      # A DynamicSupervisor managing all Singleton.Manager processes.
      {Singleton.Supervisor, name: LolApi.Singleton},
      # Telemetry Metrics
      {PrometheusTelemetry,
       metrics: [
         PrometheusTelemetry.Metrics.Finch.metrics()
       ]},
      # Rate Limiter Redis Pool
      {SharedUtils.Redis, [LolApi.Config.pool_opts(), LolApi.Config.worker_opts()]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LolApi.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # {:ok, _rate_limit_pid} = start_rate_limit_as_global()

    {:ok, pid}
  end

  def start_rate_limit_as_global() do
    [limiter_type: module, requests_per_second: rps] =
      Application.fetch_env!(:lol_api, :rate_limit)

    Singleton.start_child(
      LolApi.Singleton,
      module,
      [requests_per_second: rps],
      LolApi.RateLimit
    )
  end
end
