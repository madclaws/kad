defmodule NodeTest do
  @doc false

  # async false, since we are doing some global mutations with Application.put_env()
  # We might remove in v1
  use ExUnit.Case, async: false
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
    # If ping doesnt work nodfze 2 should get evicted.
    assert length(node_a_state.routing_table["00001"]) == 1
  end

  @tag :lookup
  test "lookup" do
    Application.put_env(:kademlia, :k, 2)
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link(node_id: 40)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    node_a_state =
      Node.update_k_buckets(node_b_state.info, node_a_state)

    node_b_state =
      Node.update_k_buckets(node_a_state.info, node_b_state)

    # Not availabel in own routing table
    assert nil == Node.lookup(2, node_b_state)

    # Available in own routing table
    assert {0, _} = Node.lookup(0, node_b_state)

    {:ok, pid3} = Node.start_link(node_id: 2)
    node_c_state = :sys.get_state(pid3)

    node_a_state =
      Node.update_k_buckets(node_c_state.info, node_a_state)

    :sys.replace_state(pid, fn _state -> node_a_state end)

    # nodeId 2 is now in node A's bucket, so we should be able to hop and find it
    assert {2, _} = Node.lookup(2, node_b_state)
  end

  @tag :skip
  test "network genesis test" do
    # https://codethechange.stanford.edu/guides/guide_kademlia.html#walkthrough-of-a-kademlia-network-genesis
    Application.put_env(:kademlia, :bitspace, 3)
    Application.put_env(:kademlia, :k, 2)
    # started bootstrap node (Node #0)
    {:ok, pid} = Node.start_link(is_bootstrap: true)

    # Started node 010
    {:ok, pid2} = Node.start_link(node_id: 2)

    node_a_state = :sys.get_state(pid) |> IO.inspect()
    node_b_state = :sys.get_state(pid2) |> IO.inspect()

    # node_a_state =
    #   Node.update_k_buckets(node_b_state.info, node_a_state) |> IO.inspect()

    # node_b_state =
    #   Node.update_k_buckets(node_a_state.info, node_b_state)

    :sys.replace_state(pid, fn _state -> node_a_state end)
    :sys.replace_state(pid2, fn _state -> node_b_state end)

    Node.lookup(2, node_a_state) |> IO.inspect()
    # # Not available in own routing table
    # assert Node.lookup(2, node_b_state) == nil

    # # Available in own routing table
    # assert {0, _} = Node.lookup(0, node_b_state)

    # {:ok, pid3} = Node.start_link(node_id: 2)
    # node_c_state = :sys.get_state(pid3)

    # node_a_state =
    #   Node.update_k_buckets(node_c_state.info, node_a_state)

    # :sys.replace_state(pid, fn _state -> node_a_state end)

    # # nodeId 2 is now in node A's bucket, so we should be able to hop and find it
    # assert {2, _} = Node.lookup(2, node_b_state)
  end
end
