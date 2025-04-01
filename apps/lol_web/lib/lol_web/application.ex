defmodule LolWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LolWeb.Telemetry,
      {PrometheusTelemetry,
       exporter: [enabled?: true],
       metrics: [
         PrometheusTelemetry.Metrics.Cowboy.metrics(),
         PrometheusTelemetry.Metrics.Phoenix.metrics(),
       ]},
      # Start a worker by calling: LolWeb.Worker.start_link(arg)
      # {LolWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      LolWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LolWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LolWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
