defmodule KademliaTest do
  use ExUnit.Case
  doctest Kademlia

  test "greets the world" do
    assert Kademlia.hello() == :world
  end
end
