defmodule SharedUtils.Redis.Pool do
  alias SharedUtils.Redis.Error

  require Logger

  @type pool_config :: %{
          required(:pool_name) => atom(),
          optional(:registration_scope) => atom(),
          optional(:pool_size) => pos_integer(),
          optional(:max_overflow) => pos_integer(),
          optional(:strategy) => atom()
        }
  @type worker_config :: %{
          optional(:host) => String.t(),
          optional(:port) => pos_integer(),
          optional(:database) => pos_integer
        }
  @type child_spec_tuple ::
          {atom(), {module(), atom(), [any()]}, :permanent | :temporary | :transient, timeout(),
           :worker | :supervisor, [module()]}

  @spec child_spec([pool_config() | worker_config()]) :: child_spec_tuple()
  def child_spec([pool_config, worker_config]) do
    pool_name =
      Map.fetch!(pool_config, :pool_name)

    :poolboy.child_spec(
      pool_name,
      pool_args(pool_config),
      worker_args(worker_config)
    )
  end

  @spec start_link([pool_config() | worker_config()]) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link([pool_config, worker_config]) do
    pool_args = pool_args(pool_config)
    worker_args = worker_args(worker_config)

    Logger.debug("""
    [SharedUtils.Redis.Pool] starting Redis pool. 
    Details: 
      #{inspect(pool_args, pretty: true)}, 
      #{inspect(worker_args, pretty: true)}
    """)

    :poolboy.start_link(pool_args, worker_args)
  end

  defp pool_args(config) do
    pool_name =
      Map.fetch!(config, :pool_name)

    registration_scope =
      Map.get(config, :registration_scope, :local)

    pool_size =
      Map.get(config, :pool_size, 10)

    max_overflow =
      Map.get(config, :max_overflow, 10)

    strategy =
      Map.get(config, :strategy, :lifo)

    [
      name: {registration_scope, pool_name},
      worker_module: Redix,
      size: pool_size,
      max_overflow: max_overflow,
      strategy: strategy
    ]
  end

  defp worker_args(config) do
    host =
      Map.get(config, :host, "localhost")

    port =
      Map.get(config, :port, 6379)

    database =
      Map.get(config, :database, 0)

    [host: host, port: port, database: database]
  end

  @spec with_pool(
          command :: list(),
          pool_name :: atom(),
          on_success_fun :: (any() -> r)
        ) :: r | {:error, ErrorMessage.t()}
        when r: var
  def with_pool(command, pool_name, on_success_fun) do
    :poolboy.transaction(pool_name, fn pid ->
      case Redix.command(pid, command) do
        {:ok, result} -> on_success_fun.(result)
        {:error, reason} -> {:error, Error.to_error_message(reason)}
      end
    end)
  end
end
