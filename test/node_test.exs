defmodule NodeTest do
  @doc false

  use ExUnit.Case
  alias Kademlia.Node

  test "creating a bootstrapped node" do
    {:ok, pid} = Node.start_link(is_bootstrap: true)

    assert Node.get_id(pid) == 0
  end

  test "creating a non-bootstrapped node" do
    {:ok, pid} = Node.start_link()

    assert Node.get_id(pid) > 0
  end

  test "Check basic routing table generation" do
    {:ok, pid} = Node.start_link(is_bootstrap: true)

    assert %{
             "1" => _,
             "000001" => _,
             "00001" => _,
             "0001" => _,
             "001" => _,
             "01" => _
           } = Node.get_routing_table(pid)
  end

  @tag :ping
  test "Check ping/ping" do
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link()
    assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
  end

  test "updating k-buckets" do
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link()
    assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
  end
end
