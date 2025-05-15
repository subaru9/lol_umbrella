defmodule LolApi.RedisCase do
  use ExUnit.CaseTemplate

  alias SharedUtils.Test.Support.RedisSandbox
  alias SharedUtils.Redis.Pool

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
