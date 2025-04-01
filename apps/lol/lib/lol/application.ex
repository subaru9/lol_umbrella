defmodule Lol.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Lol.Repo,
      {DNSCluster, query: Application.get_env(:lol, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Lol.PubSub},
      {PrometheusTelemetry,
       metrics: [
         PrometheusTelemetry.Metrics.VM.metrics()
       ]}
      # Start a worker by calling: Lol.Worker.start_link(arg)
      # {Lol.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Lol.Supervisor)
  end
end
