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

  @tag :k
  test "updating k-buckets" do
    Application.put_env(:kademlia, :k, 1)
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link(node_id: 2)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    n_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{2, _}] = n_state.routing_table["00001"]

    {:ok, pid3} = Node.start_link(node_id: 3)
    node_c_state = :sys.get_state(pid3)
    state = Node.update_k_buckets(node_c_state.info, n_state)
    # Making sure if Ping to node_2 works then we discard the incoming node
    assert length(state.routing_table["00001"]) == 1
  end

  @tag :k1
  test "updating k-buckets with K=2" do
    Application.put_env(:kademlia, :k, 2)
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link(node_id: 2)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    n_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{2, _}] = n_state.routing_table["00001"]

    {:ok, pid3} = Node.start_link(node_id: 3)
    node_c_state = :sys.get_state(pid3)
    state = Node.update_k_buckets(node_c_state.info, n_state)
    # Making sure if Ping to node_2 works then we append the new node
    assert length(state.routing_table["00001"]) == 2
    # IO.inspect(state.routing_table)
    assert [{2, _}, {3, _}] = state.routing_table["00001"]
  end

  @tag :k2
  test "updating k-buckets with K=1, discarding the lru if ping fails" do
    Application.put_env(:kademlia, :k, 1)
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link(node_id: 2)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    node_a_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{2, _}] = node_a_state.routing_table["00001"]

    {:ok, pid3} = Node.start_link(node_id: 3)
    node_c_state = :sys.get_state(pid3)
    node_a_state = Node.update_k_buckets(node_c_state.info, node_a_state)
    # If ping doesnt work node 2 should get evicted.
    assert length(node_a_state.routing_table["00001"]) == 1

  end
end
