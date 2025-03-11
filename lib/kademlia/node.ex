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

  def ping(sender_info, receiver) do
    GenServer.call(receiver, {:ping, sender_info})
  end

  def find_node(sender_info, receiver, node_id) do
    GenServer.call(receiver, {:find_node, node_id, sender_info})
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

  def handle_call({:find_node, id, _sender_info}, _from, state) do
    # TODO: This should be recursive from a caller point of view.
    # finding the closest nodes to id from the routing table
    closest_nodes =
      get_closest_nodes(id, state)

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
    node_id_bin =
      Integer.to_string(node_id, 2)
      |> Utils.format_bin_id(Application.get_env(:kademlia, :bitspace, @default_bitspace))

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
          # liveness check can be used for ping
          if Process.alive?(elem(lru, 1)) do
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

  # TODO: not doing any parallel lookup now
  @spec lookup({non_neg_integer(), pid()}, map()) :: {{non_neg_integer(), pid()} | nil, map()}
  def lookup({id, _pid} = _node_info, state) do
    # state = update_k_buckets(node_info, state)
    closest_nodes = get_closest_nodes(id, state) |> Enum.into(MapSet.new())
    node_info = do_lookup_nodes(id, closest_nodes, state, MapSet.size(closest_nodes), nil)
    {node_info, state}
  end

  # will implement the alpha node slice later...
  @spec get_closest_nodes(non_neg_integer(), map()) :: list()
  defp get_closest_nodes(id, state) do
    # TODO: can optimize to take from the closer routing tables first as per the paper
    Map.values(state.routing_table)
    |> List.flatten()
    |> Enum.sort_by(fn {node_id, _} ->
      Bitwise.bxor(node_id, id)
    end)
    |> Enum.slice(0..state.k)
  end

  @spec do_lookup_nodes(
          non_neg_integer(),
          MapSet.t(),
          map(),
          integer(),
          {non_neg_integer(), pid()} | nil
        ) ::
          {integer(), pid()} | nil
  # if we get the correct node, then we can just return that and stop the lookup process
  defp do_lookup_nodes(_, _, _, _, result_node) when is_tuple(result_node), do: result_node

  # if new_node_count is 0, ie means we got no new nodes from last round of lookup, ie
  # we start go in circles, so stop & return nil
  defp do_lookup_nodes(_, _, _, 0, _), do: nil

  defp do_lookup_nodes(id, closest_nodes, state, new_nodes_count, _result_node) do
    node =
      Enum.find(closest_nodes, fn {node_id, _pid} ->
        node_id == id
      end)

    if not is_nil(node) do
      IO.inspect("NODE found #{inspect(node)}")
      do_lookup_nodes(id, closest_nodes, state, new_nodes_count, node)
    else
      looked_up_nodes =
        Enum.map(closest_nodes, fn close_node_info ->
          Node.find_node(state.info, elem(close_node_info, 1), id)
        end)
        |> List.flatten()
        |> Enum.into(MapSet.new())

      # B - A
      new_nodes_count = MapSet.difference(looked_up_nodes, closest_nodes) |> MapSet.size()

      if new_nodes_count == 0 do
        do_lookup_nodes(id, closest_nodes, state, new_nodes_count, nil)
      else
        closest_nodes = MapSet.union(looked_up_nodes, closest_nodes)
        do_lookup_nodes(id, closest_nodes, state, new_nodes_count, nil)
      end
    end
  end

  @spec create_initial_state(Keyword.t()) :: map()
  defp create_initial_state(args) do
    bitspace = Application.get_env(:kademlia, :bitspace, @default_bitspace)
    # for now let the bootstrap node has the 0 id.
    node_id =
      cond do
        Keyword.get(args, :is_bootstrap, false) ->
          0

        not is_nil(Keyword.get(args, :node_id, nil)) ->
          Keyword.get(args, :node_id)

        true ->
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
