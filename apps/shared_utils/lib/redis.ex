defmodule SharedUtils.Redis do
  @moduledoc """
  A unified interface for Redis operations, combining pooling and high-level commands.
  """

  alias SharedUtils.Redis.Pool

  defdelegate child_spec(opts), to: Pool
  defdelegate with_pool(command, pool_name, on_success), to: Pool
end
