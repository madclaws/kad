defmodule Kad.Node do
  @moduledoc """
  Represents a real-world computer/node
  """
  alias Kad.Node
  @default_k "4"

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
    bitspace = System.get_env("kad_bit_space", "160") |> String.to_integer()
    node_id = get_node_id(args, bitspace)

    node_name =
      if bitspace != 160 do
        "node_#{node_id}" |> String.to_atom()
      else
        node_id
      end

    args = Keyword.put(args, :name, node_name)

    if is_nil(Keyword.get(args, :is_bootstrap)) do
      GenServer.start_link(__MODULE__, args, name: {:global, node_name})
    else
      GenServer.start_link(__MODULE__, args, name: {:global, :genesis})
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

  def get_state(pid, arg) do
    GenServer.call(pid, {:state, arg})
  end

  ################
  def init(args) do
    # Process.flag(:trap_exit, true)
    {:ok, create_initial_state(args), {:continue, :join_network}}
  end

  def handle_call({:get, key}, {_caller_pid, _}, state) do
    Logger.info("NODE #{state.name}:: GET operation for KEY #{key}", ansi_color: :blue)

    key =
      if state.bitspace == 160 do
        Utils.generate_key_id(key)
      else
        key
      end

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
    Logger.info("NODE #{state.name}:: PUT operation for KEY #{key} VAL #{val}",
      ansi_color: :magenta
    )

    key =
      if state.bitspace == 160 do
        Utils.generate_key_id(key)
      else
        key
      end

    closest_nodes = [state.info | lookup(key, state)]

    Enum.each(closest_nodes, fn {_node_id, pid} ->
      Node.store(pid, key, val)
    end)

    {:reply, val, state}
  end

  def handle_call({:find_node, id, {sender_id, _pid} = sender_info}, _from, state) do
    closest_nodes =
      get_closest_nodes(id, state, sender_id)

    # when a node gets a find_node request, it adds the requestee node details
    # to its own routing table
    state = update_k_buckets(sender_info, state)

    {:reply, closest_nodes, state}
  end

  def handle_call({:find_value, key}, _from, state) do
    {:reply, Map.get(state.hash_map, key), state}
  end

  def handle_call({:ping, {send_id, _send_pid}}, _, state) do
    Logger.info("NODE #{state.name}:: Got ping from #{send_id}")
    {:reply, :pong, state}
  end

  def handle_call({:state, arg}, _from, state) do
    metadata =
      case arg do
        :map ->
          Logger.info("NODE #{state.name}: local hash map", ansi_color: :yellow)
          state.hash_map

        :table ->
          Logger.info("NODE #{state.name}: routing table", ansi_color: :yellow)
          state.routing_table

        _ ->
          Logger.info("NODE #{state.name}: state", ansi_color: :yellow)
          state
      end

    IO.inspect(metadata, label: state.name)
    {:reply, :ok, state}
  end

  def handle_cast({:store, key, value}, state) do
    hash_map = Map.put(state.hash_map, key, value)
    {:noreply, %{state | hash_map: hash_map}}
  end

  def handle_continue(:join_network, state) do
    if not state.bootstrap? do
      # Add bootstrap node info to the bucket
      pid = :global.whereis_name(:genesis)
      bootstrap_node_id = Node.get_id(pid)
      state = update_k_buckets({bootstrap_node_id, pid}, state)
      lookup(elem(state.info, 0), state)
      {:noreply, state}
    else
      {:noreply, state}
    end

    {:noreply, state}
  end

  def handle_info({:update_k_buckets, closest_nodes}, state) do
    Enum.reduce(closest_nodes, state, fn node_info, state ->
      update_k_buckets(node_info, state)
    end)
    |> then(&{:noreply, &1})
  end

  def handle_info({:EXIT, pid, _}, state) do
    Logger.info("#{inspect(pid)} down")
    {:noreply, state}
  end

  @doc """
  On get to know about a node, we try to add that node in our k-buckets
  """
  @spec update_k_buckets({non_neg_integer(), pid()}, map()) :: map()
  # we don't want to add ourselves in our own routing table ;)
  def update_k_buckets({node_id, _pid} = _node_info, %{info: {node_id, _}} = state), do: state

  def update_k_buckets({node_id, _pid} = node_info, state) do
    # find the bucket
    common_prefix =
      Utils.get_common_prefix(
        elem(state.info, 0),
        node_id,
        state.bitspace
      )

    {bucket, routing_table} =
      Map.get_and_update(state.routing_table, common_prefix, fn
        cur_val when is_nil(cur_val) ->
          {[], []}

        cur_val ->
          {cur_val, cur_val}
      end)

    state = Map.put(state, :routing_table, routing_table)

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

    Logger.debug(
      "NODE: #{state.name}: Next round of hopping with closest nodes #{inspect(Enum.into(closest_nodes, []))}",
      ansi_color: :green
    )

    do_lookup_nodes(id, closest_nodes, closest_nodes, state, MapSet.size(closest_nodes), nil)
  end

  # will implement the alpha node slice later...
  @spec get_closest_nodes(non_neg_integer(), map()) :: list()
  defp get_closest_nodes(id, state, sender_node_id \\ nil) do
    # TODO: can optimize to take from the closer routing tables first as per the paper
    nodes =
      Map.values(state.routing_table)
      |> List.flatten()

    if is_nil(sender_node_id) do
      nodes
    else
      Enum.filter(nodes, fn {id, _pid} ->
        id != sender_node_id
      end)
    end
    |> Enum.sort_by(fn {node_id, _} ->
      Utils.find_distance(node_id, id)
    end)
    |> Enum.slice(0..(state.k - 1))
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
      Utils.find_distance(node_id, id)
    end)
    |> Enum.slice(0..(state.k - 1))
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
      Logger.debug("NODE: #{state.name}: Node found #{inspect(node)}",
        ansi_color: :yellow
      )

      do_lookup_nodes(id, closest_nodes, to_lookup_nodes, state, new_nodes_count, node)
    else
      # Get all the closest nodes of the to_lookup_nodes
      looked_up_nodes =
        Enum.map(to_lookup_nodes, fn close_node_info ->
          # We don't want to send a find_node to ourselves
          if elem(close_node_info, 0) != elem(state.info, 0) do
            try do
              Node.find_node(state.info, elem(close_node_info, 1), id)
            catch
              _, _ ->
                IO.inspect(:crash)
                []
            end
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

        Logger.debug(
          "NODE: #{state.name}: Next round of hopping with *NEW* found nodes #{inspect(Enum.into(to_lookup_nodes, []))}",
          ansi_color: :green
        )

        do_lookup_nodes(id, closest_nodes, to_lookup_nodes, state, new_nodes_count, nil)
      end
    end
  end

  @spec create_initial_state(Keyword.t()) :: map()
  defp create_initial_state(args) do
    bitspace = System.get_env("kad_bit_space", "160") |> String.to_integer()
    # for now let the bootstrap node has the 0 id.
    node_id =
      cond do
        not is_nil(Keyword.get(args, :node_id, nil)) ->
          Keyword.get(args, :node_id)

        bitspace == 160 ->
          Utils.generate_node_id(bitspace)

        Keyword.get(args, :is_bootstrap, false) ->
          0

        true ->
          Utils.generate_node_id(bitspace)
      end

    name = if Keyword.get(args, :is_bootstrap), do: :genesis, else: Keyword.get(args, :name)

    Logger.info(
      "Node started with ID: #{name}, PID: #{inspect(self())}, bootstrap_node?: #{Keyword.get(args, :is_bootstrap, false)}"
    )

    %{
      k: Keyword.get(args, :k, System.get_env("kad_k", @default_k) |> String.to_integer()),
      # alpha: max concurrency lookups
      a: Application.get_env(:kad, :a, @default_a),
      info: {node_id, self()},
      hash_map: %{},
      routing_table: %{},
      bitspace: bitspace,
      bootstrap?: Keyword.get(args, :is_bootstrap, false),
      name: name
    }
  end

  @spec get_node_id(Keyword.t(), non_neg_integer()) :: non_neg_integer() | String.t()
  defp get_node_id(args, bitspace) do
    cond do
      not is_nil(Keyword.get(args, :node_id, nil)) ->
        Keyword.get(args, :node_id)

      bitspace == 160 ->
        Utils.generate_node_id(bitspace)

      Keyword.get(args, :is_bootstrap, false) ->
        0

      true ->
        Utils.generate_node_id(bitspace)
    end
  end

  # Randomly generate buckets and call update_k_buckets
  # defp refresh_buckets() do
  # end
end
