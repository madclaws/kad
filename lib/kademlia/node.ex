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
    # only bootstrapped node will be named node, so that other processes
    # can find the bootstrapped node while they are booting up
    if is_nil(Keyword.get(args, :is_bootstrap)) do
      GenServer.start_link(__MODULE__, args, [])
    else
      GenServer.start_link(__MODULE__, args, name: :genesis)
    end
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

  def find_node({_id, _pid} = sender_info, receiver, node_id) do
    GenServer.call(receiver, {:find_node, node_id, sender_info})
  end

  # make sure the put hashes into a number
  @spec find_value(pid(), non_neg_integer()) :: any()
  def find_value(receiver_pid, key) do
    GenServer.call(receiver_pid, {:find_value, key})
  end

  # make sure the put hashes into a number
  @spec store(pid(), non_neg_integer(), any()) :: any()
  def store(receiver_pid, key, value) do
    GenServer.cast(receiver_pid, {:store, key, value})
  end

  def get_id(pid) do
    :sys.get_state(pid).info |> elem(0)
  end

  def get_routing_table(pid) do
    :sys.get_state(pid).routing_table
  end

  ################
  def init(args) do
    {:ok, create_initial_state(args), {:continue, :join_network}}
  end

  def handle_call({:get, key}, {_caller_pid, _}, state) do
    Logger.info("NODE #{elem(state.info, 0)}:: GET operation for KEY #{key}")
    # TODO: when we make generic, we have to hash it to a number.

    closest_nodes = lookup(key, state)

    case Map.get(state.hash_map, key) do
      nil ->
        Enum.reduce_while(closest_nodes, nil, fn {_node_id, pid}, value ->
          val = Node.find_value(pid, key)

          if is_nil(val) do
            {:cont, value}
          else
            {:halt, val}
          end
        end)

      val ->
        val
    end
    |> then(&{:reply, &1, state})
  end

  def handle_call({:put, key, val}, {_caller_pid, _}, state) do
    Logger.info("NODE #{elem(state.info, 0)}:: PUT operation for KEY #{key} VAL #{val}")

    # TODO: when we make generic, we have hash it to a number.

    closest_nodes = [state.info | lookup(key, state)]

    Enum.each(closest_nodes, fn {_node_id, pid} ->
      Node.store(pid, key, val)
    end)

    {:reply, val, state}
  end

  def handle_call({:find_node, id, {_sender_id, _pid} = sender_info}, _from, state) do
    closest_nodes =
      get_closest_nodes(id, state)

    # when a node gets a find_node request, it adds the requestee node details
    # to its own routing table
    state = update_k_buckets(sender_info, state)

    {:reply, closest_nodes, state}
  end

  def handle_call({:find_value, key}, _from, state) do
    {:reply, Map.get(state.hash_map, key), state}
  end

  def handle_call({:ping, {send_id, _send_pid}}, _, state) do
    Logger.info("NODE #{elem(state.info, 0)}:: Got ping from #{send_id}")
    {:reply, :pong, state}
  end

  def handle_cast({:store, key, value}, state) do
    hash_map = Map.put(state.hash_map, key, value)
    {:noreply, %{state | hash_map: hash_map}}
  end

  def handle_continue(:join_network, state) do
    # if nodeID is 0, then we dont do anything
    if elem(state.info, 0) > 0 do
      # Add bootstrap node info to the bucket
      pid = Process.whereis(:genesis)
      state = update_k_buckets({0, pid}, state)
      lookup(elem(state.info, 0), state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:update_k_buckets, closest_nodes}, state) do
    Enum.reduce(closest_nodes, state, fn node_info, state ->
      update_k_buckets(node_info, state)
    end)
    |> then(&{:noreply, &1})
  end

  @doc """
  On get to know about a node, we try to add that node in our k-buckets
  """
  @spec update_k_buckets({non_neg_integer(), pid()}, map()) :: map()
  # we don't want to add ourselves in our own routing table ;)
  def update_k_buckets({node_id, _pid} = _node_info, %{info: {node_id, _}} = state), do: state

  def update_k_buckets({node_id, _pid} = node_info, state) do
    node_id_bin =
      Integer.to_string(node_id, 2)
      |> Utils.format_bin_id(Application.get_env(:kademlia, :bitspace, @default_bitspace))

    # find the bucket
    common_prefix =
      Map.keys(state.routing_table)
      |> Enum.find(fn k -> String.starts_with?(node_id_bin, k) end)

    # IO.inspect()
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
  # Returns either the lookedup node or list of k-closest nodes
  @spec lookup(non_neg_integer(), map()) :: [{non_neg_integer(), pid()}]
  def lookup(id, state) do
    closest_nodes = get_closest_nodes(id, state) |> Enum.into(MapSet.new())

    Logger.debug("Next round of hopping with closest nodes #{inspect(closest_nodes)}",
      ansi_color: :green
    )

    do_lookup_nodes(id, closest_nodes, closest_nodes, state, MapSet.size(closest_nodes), nil)
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
          MapSet.t(),
          map(),
          integer(),
          {non_neg_integer(), pid()} | nil
        ) ::
          list({integer(), pid()})
  # if we get the correct node, then we can just return that and stop the lookup process
  defp do_lookup_nodes(_, closest_nodes, _, _, _, result_node) when is_tuple(result_node) do
    # once we get correct node/nil, we update the new nodes we got to
    # know into our k-buckets
    Process.send(self(), {:update_k_buckets, closest_nodes}, [])
    [result_node]
  end

  # if new_node_count is 0, ie means we got no new nodes from last round of lookup, ie
  # we start to go in circles, so stop & return k closest-nodes
  defp do_lookup_nodes(id, closest_nodes, _, state, 0, _) do
    # once we get correct node/nil, we update the new nodes we got to
    # know into our k-buckets
    Process.send(self(), {:update_k_buckets, closest_nodes}, [])

    closest_nodes
    |> Enum.sort_by(fn {node_id, _} ->
      Bitwise.bxor(node_id, id)
    end)
    |> Enum.slice(0..state.k)
  end

  # closest_nodes - This will be an accumulation of all the closest_nodes we get from hopping
  # to_lookup_nodes - These are the unique nodes to which we can do a lookup in the next round
  # this variable makes sure that we are not re-looking already visited nodes
  defp do_lookup_nodes(id, closest_nodes, to_lookup_nodes, state, new_nodes_count, _result_node) do
    node =
      Enum.find(to_lookup_nodes, fn {node_id, _pid} ->
        node_id == id
      end)

    if not is_nil(node) do
      IO.inspect("NODE found #{inspect(node)}")
      do_lookup_nodes(id, closest_nodes, to_lookup_nodes, state, new_nodes_count, node)
    else
      # Get all the closest nodes of the to_lookup_nodes
      looked_up_nodes =
        Enum.map(to_lookup_nodes, fn close_node_info ->
          # TODO: Handle the timeout failure
          # We don't want to send a find_node to ourselves
          if elem(close_node_info, 0) != elem(state.info, 0) do
            Node.find_node(state.info, elem(close_node_info, 1), id)
          else
            []
          end
        end)
        |> List.flatten()
        |> Enum.into(MapSet.new())

      # B - A
      to_lookup_nodes = MapSet.difference(looked_up_nodes, closest_nodes)

      new_nodes_count = MapSet.size(to_lookup_nodes)

      if new_nodes_count == 0 do
        do_lookup_nodes(id, closest_nodes, to_lookup_nodes, state, new_nodes_count, nil)
      else
        closest_nodes = MapSet.union(looked_up_nodes, closest_nodes)

        Logger.debug("Next round of hopping with new found nodes #{inspect(to_lookup_nodes)}",
          ansi_color: :green
        )

        do_lookup_nodes(id, closest_nodes, to_lookup_nodes, state, new_nodes_count, nil)
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
