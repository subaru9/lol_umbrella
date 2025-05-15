defmodule SharedUtils.Test.Support.RedisSandbox do
  use Agent

  def start_link(opts \\ []) do
    {initial_state, _} = Keyword.pop(opts, :db_set, MapSet.new(1..16))
    {name, _} = Keyword.pop(opts, :name, __MODULE__)
    Agent.start_link(fn -> initial_state end, name: name)
  end

  def check_out(name \\ __MODULE__) do
    Agent.get_and_update(name, fn state ->
      case MapSet.to_list(state) do
        [db_number | rest] ->
          {db_number, MapSet.new(rest)}

        [] ->
          raise("no dbs available")
      end
    end)
  end

  def check_in(name \\ __MODULE__, db_number) do
    Agent.update(name, fn state ->
      MapSet.put(state, db_number)
    end)
  end
end
