# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config, only: [config: 2, config: 3, import_config: 1, config_env: 0, config_target: 0]

# Configure Mix tasks and generators
config :lol_api, :env, config_env()
config :lol_api, :api_key, System.get_env("RIOT_API_KEY")

config :lol,
  ecto_repos: [Lol.Repo]

config :lol_web,
  ecto_repos: [Lol.Repo],
  generators: [context_app: :lol]

# Configures the endpoint
config :lol_web, LolWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: LolWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Lol.PubSub,
  live_view: [signing_salt: "QRVhrvb0"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  lol_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/lol_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  lol_web: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/lol_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
