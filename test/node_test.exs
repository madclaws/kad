defmodule NodeTest do
  @doc false

  # async false, since we are doing some global mutations with Application.put_env()
  # We might remove in v1
  use ExUnit.Case, async: false
  alias Kad.Node

  setup do
    System.put_env("kad_bit_space", "160")
    System.put_env("kad_k", "4")
  end

  test "creating a bootstrapped node" do
    {:ok, pid} = Node.start_link(is_bootstrap: true)

    refute is_nil(Node.get_id(pid))
  end

  @tag :t
  test "creating a non-bootstrapped node" do
    {:ok, _pid} = Node.start_link(is_bootstrap: true)
    {:ok, _pid} = Node.start_link()
  end

  @tag :ping
  test "Check ping/ping" do
    {:ok, pid} = Node.start_link(is_bootstrap: true)
    {:ok, pid2} = Node.start_link()
    assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
  end

  @tag :k
  test "updating k-buckets, 6-bit space" do
    System.put_env("kad_bit_space", "6")
    Application.put_env(:kad, :k, 1)
    {:ok, pid} = Node.start_link(is_bootstrap: true, k: 1)
    {:ok, pid2} = Node.start_link(node_id: 2, k: 1)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    n_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{2, _}] = n_state.routing_table["00001"]

    {:ok, pid3} = Node.start_link(node_id: 3, k: 1)
    node_c_state = :sys.get_state(pid3)
    state = Node.update_k_buckets(node_c_state.info, n_state)
    # Making sure if Ping to node_2 works then we discard the incoming node
    assert length(state.routing_table["00001"]) == 1
  end

  @tag :kk
  test "updating k-buckets, 160-bit space" do
    System.put_env("kad_bit_space", "160")
    Application.put_env(:kad, :k, 1)

    {:ok, pid} =
      Node.start_link(
        node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50d",
        is_bootstrap: true,
        k: 1
      )

    {:ok, pid2} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94594", k: 1)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    n_state = Node.update_k_buckets(node_b_state.info, node_a_state)

    assert [{_, _}] = n_state.routing_table["1"]

    {:ok, pid3} = Node.start_link(node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50e", k: 1)
    node_c_state = :sys.get_state(pid3)
    state = Node.update_k_buckets(node_c_state.info, n_state)
    # Making sure if Ping to node_2 works then we discard the incoming node
    assert length(state.routing_table["1"]) == 1
  end

  @tag :k1
  test "updating k-buckets with K=2, with 6-bit space" do
    System.put_env("kad_bit_space", "6")
    Application.put_env(:kad, :k, 2)
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

  @tag :k1
  test "updating k-buckets with K=2, with 160-bit space" do
    Application.put_env(:kad, :k, 2)

    {:ok, pid} =
      Node.start_link(node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50d", is_bootstrap: true)

    {:ok, pid2} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94594")
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    n_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{_, _}] = n_state.routing_table["1"]

    {:ok, pid3} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94593")
    node_c_state = :sys.get_state(pid3)
    state = Node.update_k_buckets(node_c_state.info, n_state)
    # Making sure if Ping to node_2 works then we append the new node
    assert [{_, _}, {_, _}] = state.routing_table["1"]
  end

  @tag :k2
  test "updating k-buckets with K=1, discarding the lru if ping fails, 6-bit space" do
    System.put_env("kad_bit_space", "6")
    {:ok, pid} = Node.start_link(is_bootstrap: true, k: 1)
    {:ok, pid2} = Node.start_link(node_id: 2, k: 1)
    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    node_a_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{2, _}] = node_a_state.routing_table["00001"]

    {:ok, pid3} = Node.start_link(node_id: 3, k: 1)
    node_c_state = :sys.get_state(pid3)
    node_a_state = Node.update_k_buckets(node_c_state.info, node_a_state)
    # If ping doesnt work nodfze 2 should get evicted.
    assert length(node_a_state.routing_table["00001"]) == 1
  end

  @tag :k2
  test "updating k-buckets with K=1, discarding the lru if ping fails, 160-bit space" do
    {:ok, pid} =
      Node.start_link(
        node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50d",
        is_bootstrap: true,
        k: 1
      )

    {:ok, pid2} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94594", k: 1)
    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    node_a_state = Node.update_k_buckets(node_b_state.info, node_a_state)
    assert [{_, _}] = node_a_state.routing_table["1"]

    {:ok, pid3} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94593", k: 1)
    node_c_state = :sys.get_state(pid3)
    node_a_state = Node.update_k_buckets(node_c_state.info, node_a_state)
    # If ping doesnt work nodfze 2 should get evicted.
    assert length(node_a_state.routing_table["1"]) == 1
  end

  @tag :lookup
  test "lookup, 6-bit space" do
    System.put_env("kad_bit_space", "6")

    {:ok, pid} = Node.start_link(is_bootstrap: true)

    {:ok, pid2} = Node.start_link(node_id: 40)

    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    Process.sleep(1000)
    # |> IO.inspect()
    _node_a_state = :sys.get_state(pid)
    # |> IO.inspect()
    node_b_state = :sys.get_state(pid2)

    # # Not availabel in own routing table
    assert [{0, _}] = Node.lookup(2, node_b_state)

    # # Available in own routing table
    assert [{0, _}] = Node.lookup(0, node_b_state)

    {:ok, pid3} = Node.start_link(node_id: 2)

    Process.sleep(100)

    node_c_state = :sys.get_state(pid3)

    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    node_a_state =
      Node.update_k_buckets(node_c_state.info, node_a_state)

    :sys.replace_state(pid, fn _state -> node_a_state end)

    # # nodeId 2 is now in node A's bucket, so we should be able to hop and find it
    assert [{2, _}] = Node.lookup(2, node_b_state)
  end

  @tag :lookup
  test "lookup, 160-bit space" do
    {:ok, pid} =
      Node.start_link(node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50d", is_bootstrap: true)

    {:ok, pid2} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94594")

    # assert :pong == Node.ping(:sys.get_state(pid).info, pid2)
    Process.sleep(1000)
    # |> IO.inspect()
    _node_a_state = :sys.get_state(pid)
    # |> IO.inspect()
    node_b_state = :sys.get_state(pid2)

    # # Not availabel in own routing table
    assert [{_, _}] = Node.lookup("203552f416eaa2ee284aff44dfd352dcc5c94594", node_b_state)

    # # Available in own routing table
    assert [{_, _}] = Node.lookup("c7c6873f1ca45c8414d85b17f543d1e332a5a50d", node_b_state)

    {:ok, pid3} = Node.start_link(node_id: "203552f416eaa2ee284aff44dfd352dcc5c94591")

    Process.sleep(100)

    node_c_state = :sys.get_state(pid3)

    node_a_state = :sys.get_state(pid)
    node_b_state = :sys.get_state(pid2)

    node_a_state =
      Node.update_k_buckets(node_c_state.info, node_a_state)

    :sys.replace_state(pid, fn _state -> node_a_state end)

    # # nodeId 4591 is now in node A's bucket, so we should be able to hop and find it
    assert [{"203552f416eaa2ee284aff44dfd352dcc5c94591", _}] =
             Node.lookup("203552f416eaa2ee284aff44dfd352dcc5c94591", node_b_state)
  end

  @tag :put
  test "put/get for genesis node, 6-bit space" do
    System.put_env("kad_bit_space", "6")
    Application.put_env(:kad, :k, 2)
    {:ok, pid} = Node.start_link(is_bootstrap: true)

    assert "hello" = Node.put(pid, 20, "hello")

    assert "hello" = Node.get(pid, 20)
  end

  @tag :put
  test "put/get for genesis node, 160-bit space" do
    Application.put_env(:kad, :k, 2)

    {:ok, pid} =
      Node.start_link(node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50d", is_bootstrap: true)

    assert "hello" = Node.put(pid, 20, "hello")

    assert "hello" = Node.get(pid, 20)
  end

  @tag :puta
  test "PUT on node_b and query from genesis node" do
    System.put_env("kad_bit_space", "6")

    Application.put_env(:kad, :k, 1)
    {:ok, pid} = Node.start_link(is_bootstrap: true, k: 1)

    {:ok, pid2} = Node.start_link(node_id: 40, k: 1)
    {:ok, pid3} = Node.start_link(node_id: 60, k: 1)

    Process.sleep(1000)
    assert "hello" = Node.put(pid3, 50, "hello")

    # Node 40 would have key 50, and node 0 wouldnt have
    # due to closeness

    assert %{hash_map: %{50 => "hello"}} = :sys.get_state(pid2)
    assert nil == get_in(:sys.get_state(pid), [:hash_map, 50])
  end

  @tag :putaa
  test "PUT on node_b and query from genesis node, 160-bit space" do
    Application.put_env(:kad, :k, 1)

    {:ok, pid} =
      Node.start_link(
        node_id: "c7c6873f1ca45c8414d85b17f543d1e332a5a50d",
        is_bootstrap: true,
        k: 1
      )

    {:ok, pid2} = Node.start_link(node_id: "b780d2b4c7bbb385854b6a7b0672226392612cb9", k: 1)
    {:ok, pid3} = Node.start_link(node_id: "1377e3c5ad52629bd0778b4dca1775062a2b7278", k: 1)

    Process.sleep(1000)
    assert "hello" = Node.put(pid3, 50, "hello")

    # Node 40 would have key 50, and node 0 wouldnt have
    # due to closeness

    assert %{hash_map: %{"b7bdfaa02a991e5f385de85a8345612572fc2c75" => "hello"}} =
             :sys.get_state(pid2)

    assert nil == get_in(:sys.get_state(pid), [:hash_map, 50])

    assert "hello" = Node.get(pid, 50)
  end
end
