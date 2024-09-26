defmodule HookshotTest do
  use ExUnit.Case
  doctest Hookshot

  test "greets the world" do
    assert Hookshot.hello() == :world
  end
end
