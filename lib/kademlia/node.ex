defmodule Kademlia.Node do
  @moduledoc """
  Represents a real-world computer/node

  how keys can be mapped to 6-bit space?

  key will be hashed to 6-bit space..., for now lets keys be a number which is explicitly inside 6-bit space while saving..

  """
  alias Kademlia.Node

  @default_k 4
  @default_bitspace 6
  @default_a 3
  # 1 min
  @timeout :timer.seconds(60)

  use GenServer
  require Logger

  @doc """
  Pass is_bootstrap: true for node to be acting as bootstrapped node
  """
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key}, @timeout)
  end

  def put(pid, key, val) do
    GenServer.call(pid, {:put, key, val}, @timeout)
  end

  def find_node(pid, id) do
    GenServer.call(pid, {:find_node, id}, @timeout)
  end

  def ping(sender_info, receiver) do
    GenServer.call(receiver, {:ping, sender_info}, @timeout)
  end

  def get_id(pid) do
    :sys.get_state(pid).info |> elem(0)
  end

  def get_routing_table(pid) do
    :sys.get_state(pid).routing_table
  end

  ################
  def init(args) do
    {:ok, create_initial_state(args)}
  end

  def handle_call({:get, key}, {_caller_pid, _}, state) do
    Logger.info("NODE #{__MODULE__.get_id(self())}:: GET operation for KEY #{key}")
    current_bitspace = Application.get_env(:kademlia, :bitspace, @default_bitspace)

    cond do
      not is_number(key) ->
        {:reply, {:error, "Key should be number"}, state}

      key > Utils.get_max_id(current_bitspace) ->
        {:reply, {:error, "Key is out of bitspace (#{current_bitspace})"}, state}

      true ->
        {:reply, state.hash_map[key], state}
    end
  end

  def handle_call({:put, key, val}, {_caller_pid, _}, state) do
    Logger.info("NODE #{__MODULE__.get_id(self())}:: PUT operation for KEY #{key} VAL #{val}")
    current_bitspace = Application.get_env(:kademlia, :bitspace, @default_bitspace)

    if key > current_bitspace do
    end

    cond do
      not is_number(key) ->
        {:reply, {:error, "Key should be number"}, state}

      key > Utils.get_max_id(current_bitspace) ->
        {:reply, {:error, "Key is out of bitspace (#{current_bitspace})"}, state}

      true ->
        hash_map = Map.put(state.hash_map, key, val)
        state = Map.put(state, :hash_map, hash_map)
        {:reply, {:ok, val}, state}
    end
  end

  def handle_call({:find_node, id}, _from, state) do
    # finding the closest nodes to id from the routing table
    closest_nodes =
      Map.values(state.routing_table)
      |> List.flatten()
      |> Enum.sort_by(fn {node_id, _} ->
        Bitwise.bxor(node_id, id)
      end)
      |> Enum.slice(0..state.k)

    {:reply, closest_nodes, state}
  end

  def handle_call({:ping, {send_id, _send_pid}}, _, state) do
    Logger.info("NODE #{elem(state.info, 0)}:: Got ping from #{send_id}")
    {:reply, :pong, state}
  end

  @doc """
  On get to know about a node, we try to add that node in our k-buckets
  """
  @spec update_k_buckets({non_neg_integer(), pid()}, map()) :: map()
  def update_k_buckets({node_id, _pid} = node_info, state) do
    node_id_bin = Integer.to_string(node_id, 2)
    # find the bucket
    common_prefix =
      Map.keys(state.routing_table)
      |> Enum.find(fn k -> String.starts_with?(node_id_bin, k) end)

    bucket = state.routing_table[common_prefix]
    node_index = Enum.find_index(bucket, &(elem(&1, 0) == node_id))

    bucket_new =
      cond do
        node_index != nil ->
          # node is already in the bucket, lets move to the tail
          bucket = List.delete_at(bucket, node_index)
          bucket ++ [node_info]

        node_index == nil and length(bucket) < state.k ->
          # node not in bucket and bucket length less than K
          bucket ++ [node_info]

        true ->
          [lru | _] = bucket

          if Node.ping(state.node_info, elem(lru, 1)) == :pong do
            bucket = List.delete_at(bucket, 0)
            bucket ++ [lru]
          else
            bucket = List.delete_at(bucket, 0)
            bucket ++ [node_info]
          end
      end

    routing_table = Map.put(state.routing_table, common_prefix, bucket_new)
    Map.put(state, :routing_table, routing_table)
  end

  @spec create_initial_state(Keyword.t()) :: map()
  defp create_initial_state(args) do
    bitspace = Application.get_env(:kademlia, :bitspace, @default_bitspace)
    # for now let the bootstrap node has the 0 id.
    node_id =
      if Keyword.get(args, :is_bootstrap, false) do
        0
      else
        Utils.generate_node_id(bitspace)
      end

    Logger.info(
      "Node started with ID: #{node_id}, PID: #{inspect(self())}, bootstrap_node?: #{Keyword.get(args, :is_bootstrap, false)}"
    )

    routing_table = Utils.create_routing_table(node_id, bitspace)
    Logger.info("Node #{node_id}:: Routing table\n #{inspect(routing_table)}")

    %{
      k: Application.get_env(:kademlia, :k, @default_k),
      # alpha: max concurrency lookups
      a: Application.get_env(:kademlia, :a, @default_a),
      info: {node_id, self()},
      hash_map: %{},
      routing_table: routing_table
    }
  end
end
