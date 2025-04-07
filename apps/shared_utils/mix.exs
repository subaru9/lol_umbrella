defmodule SharedUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :shared_utils,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:error_message, "~> 0.3"},
      {:poolboy, "~> 1.5"},
      {:redix, "~> 1.5"}
    ]
  end
end
