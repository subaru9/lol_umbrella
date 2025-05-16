defmodule LolApi.RedisCase do
  @moduledoc """
  Isolates Redis per test via DB leasing and a supervised pool.

  Enables safe `async: true` tests without flushing shared state.
  """

  use ExUnit.CaseTemplate

  alias SharedUtils.Redis.Pool
  alias SharedUtils.Test.Support.RedisSandbox

  setup do
    database = RedisSandbox.check_out()
    pool_name = :"rate_limiter_pool_database_#{database}"

    {:ok, pid} = start_supervised({Pool, [%{pool_name: pool_name}, %{database: database}]})

    SharedUtils.Redis.with_pool(["FLUSHDB"], pool_name, fn "OK" -> :ok end)

    on_exit(fn ->
      RedisSandbox.check_in(database)
    end)

    [pool_name: pool_name, pool_pid: pid]
  end
end
