defmodule SharedUtilsTest do
  use ExUnit.Case
  doctest SharedUtils

  test "greets the world" do
    assert SharedUtils.hello() == :world
  end
end
