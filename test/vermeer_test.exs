defmodule VermeerTest do
  use ExUnit.Case
  doctest Vermeer

  test "greets the world" do
    assert Vermeer.hello() == :world
  end
end
