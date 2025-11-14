defmodule MessagingCoreTest do
  use ExUnit.Case
  doctest MessagingCore

  test "greets the world" do
    assert MessagingCore.hello() == :world
  end
end
