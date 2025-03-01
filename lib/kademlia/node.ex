defmodule Kademlia.Node do
  @moduledoc """
  Represents a real-world computer/node

  how keys can be mapped to 6-bit space?

  key will be hashed to 6-bit space..., for now lets keys be a number which is explicitly inside 6-bit space while saving..

  """

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

  def find_comp(pid, id) do
    GenServer.call(pid, {:find_comp, id}, @timeout)
  end

  def get_id(pid) do
    :sys.get_state(pid).info |> elem(1)
  end

  def get_routing_table(pid) do
    :sys.get_state(pid).routing_table
  end

  ################
  def init(args) do
    {:ok, create_initial_state(args)}
  end

  def handle_call({:get, key}, {_caller_pid, _}, state) do
    Logger.info("NODE #{elem(state.info, 1)}:: GET operation for KEY #{key}")
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
    Logger.info("NODE #{elem(state.info, 1)}:: PUT operation for KEY #{key} VAL #{val}")
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

  def handle_call({:find_comp, id}, _from, state) do
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

  def handle_info({:ping, caller}, state) do
    Process.send(caller, :pong, [])
    {:noreply, state}
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
      info: {self(), node_id},
      hash_map: %{},
      routing_table: routing_table
    }
  end
end
