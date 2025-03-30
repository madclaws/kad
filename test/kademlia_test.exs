defmodule KadTest do
  use ExUnit.Case
  doctest Kad

  @tag :clos
  test "closest k nodes from the routing table" do
    table = %{
      "00" => [{0, "adad"}],
      "010" => [{2, "adad"}],
      "1" => [{7, "adad"}, {6, "adad"}]
    }

    id = 3

    assert [{2, _}, {0, _}, {7, _}, {6, _}] =
             Map.values(table)
             |> List.flatten()
             |> Enum.sort_by(fn {a, _} ->
               Bitwise.bxor(a, id)
             end)
  end
end
