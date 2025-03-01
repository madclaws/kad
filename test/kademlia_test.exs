defmodule KademliaTest do
  use ExUnit.Case
  doctest Kademlia
  @k 2

  @tag :clos
  test "closest k nodes from the routing table" do
    table = %{
      "00" => [{0, "adad"}],
      "010" => [{2, "adad"}],
      "1" => [{7, "adad"}, {6, "adad"}]
    }

    id = 3

    Map.values(table)
    |> List.flatten()
    |> Enum.sort_by(fn {a, _} ->
      Bitwise.bxor(a, id)
    end)
    |> IO.inspect()
  end
end
