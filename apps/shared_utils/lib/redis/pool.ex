defmodule SharedUtils.Redis.Pool do
  alias SharedUtils.Redis.Error

  def child_spec(opts) do
    pool_name =
      Map.fetch!(opts, :pool_name)

    registration_scope =
      Map.get(opts, :registration_scope, :local)

    pool_size =
      Map.get(opts, :pool_size, 10)

    max_overflow =
      Map.get(opts, :max_overflow, 10)

    strategy =
      Map.get(opts, :strategy, :lifo)

    :poolboy.child_spec(
      pool_name,
      name: {registration_scope, pool_name},
      worker_module: Redix,
      size: pool_size,
      max_overflow: max_overflow,
      strategy: strategy
    )
  end

  @spec with_pool(
          command :: list(),
          pool_name :: atom(),
          on_success_fun :: function()
        ) :: ErrorMessage.t_res()
  def with_pool(command, pool_name, on_success_fun) do
    :poolboy.transaction(pool_name, fn pid ->
      case Redix.command(pid, command) do
        {:ok, result} -> on_success_fun.(result)
        {:error, reason} -> {:error, Error.to_error_message(reason)}
      end
    end)
  end
end
