defmodule LolApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :lol_api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(env) when env in [:test, :dev], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LolApi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.0"},
      {:error_message, "~> 0.3"},
      {:finch, "~> 0.19.0", override: true},
      {:jason, "~> 1.2"},
      {:prometheus_telemetry, "~> 0.4"},
      {:sandbox_registry, "~> 0.1"},
      {:singleton, "~> 1.0"},
      {:shared_utils, in_umbrella: true},
      {:timex, "~> 3.7"}
    ]
  end
end
