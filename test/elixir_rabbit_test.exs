defmodule ElixirRabbitTest do
  use ExUnit.Case
  doctest ElixirRabbit

  test "greets the world" do
    assert ElixirRabbit.hello() == :world
  end
end
