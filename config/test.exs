import Config

config :lol_api, :rate_limiter,
  pool: %{
    pool_name: :lol_api_rate_limiter_pool_test,
    registration_scope: :global,
    pool_size: 10,
    max_overflow: 10
  },
  pool_worker: %{host: "localhost", port: 6378},
  max_cooldown_ttl: 1800

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :lol, Lol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "lol_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lol_web, LolWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BEs9mCnZgbuS8gHIVsFSawnlUQmsK+xxFTHXObnvWWcKY71sxSutApp0ea5zeO3w",
  server: false

# Print only warnings and errors during test
config :logger, level: :debug

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
