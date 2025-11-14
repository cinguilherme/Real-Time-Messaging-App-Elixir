defmodule MessagingApiTest do
  use ExUnit.Case
  doctest MessagingApi

  test "greets the world" do
    assert MessagingApi.hello() == :world
  end
end
