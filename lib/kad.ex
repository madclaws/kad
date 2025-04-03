defmodule Kad do
  @moduledoc """
  Documentation for `Kad`.
  """
  require Logger

  @doc """
  Starts a node and auto join into the network

  Recommended to use once inside a simulation

  NOTE: Can pass node_id, if its minikad like `Kad.start_node(node_id: 30)`
  """
  @spec start_node(Keyword.t()) :: any()
  def start_node(args) do
    DynamicSupervisor.start_child(Kad.DynamicSupervisor, {Kad.Node, args})
  end

  @doc """
  Starts the simulation in minikad mode (ie 6 bitspace)

  args - A list of options to tune the sim network

  ## Available args

  `k` - Max k bucket (default 2)

  `observer` - Should run Erlang observer (default true)
  """
  @spec minikad(Keyword.t()) :: :ok
  def minikad(args \\ []) do
    System.put_env(
      "kad_bit_space",
      "6"
    )

    nodes = [
      2,
      50,
      60,
      15,
      35,
      10
    ]

    System.put_env("kad_k", Keyword.get(args, :k, 2) |> to_string())

    if Keyword.get(args, :observer, true) do
      :observer.start()
    end

    start_node(is_bootstrap: true)

    Enum.reduce(nodes, 1, fn node, delay ->
      start_node(node_id: node, delay: delay * 2)
      delay + 1
    end)
  end

  @doc """
  Starts the simulation in megakad mode (ie 160 bitspace)

  args - A list of options to tune the sim network

  Available args

  `k` - Max k bucket (default 4)

  `n` - No: of initial nodes in the network (default 20)

  `observer` - Should run Erlang observer (default true)
  """
  @spec megakad(Keyword.t()) :: :ok
  def megakad(args \\ []) do
    System.put_env(
      "kad_bit_space",
      "160"
    )

    System.put_env("kad_k", Keyword.get(args, :k, 4) |> to_string())

    if Keyword.get(args, :observer, true) do
      :observer.start()
    end

    start_node(is_bootstrap: true)

    for i <- 1..Keyword.get(args, :n, 20) do
      start_node(delay: i * 2)
    end
  end

  @doc """
  Connects the 2 terminals with distributed erlang
  """
  def connect_term() do
    Node.connect(:term1@localhost)
    Node.connect(:term2@localhost)
  end

  @spec get(atom(), any()) :: any()
  def get(node_id, key) do
    pid = :global.whereis_name(get_parsed_node_id(node_id))
    Kad.Node.get(pid, key)
  end

  @spec put(atom(), any(), any()) :: any()
  def put(node_id, key, val) do
    pid = :global.whereis_name(get_parsed_node_id(node_id))
    Kad.Node.put(pid, key, val)
  end

  @spec show_map(atom()) :: :ok
  def show_map(node_id) do
    pid = :global.whereis_name(get_parsed_node_id(node_id))
    Kad.Node.get_state(pid, :map)
  end

  @spec show_routing_table(atom()) :: :ok
  def show_routing_table(node_id) do
    pid = :global.whereis_name(get_parsed_node_id(node_id))
    Kad.Node.get_state(pid, :table)
  end

  @spec state(atom()) :: :ok
  def state(node_id) do
    pid = :global.whereis_name(get_parsed_node_id(node_id))
    Kad.Node.get_state(pid, :state)
  end

  @spec get_parsed_node_id(number() | String.t()) :: atom() | String.t()
  defp get_parsed_node_id(node_id) do
    if is_number(node_id) do
      String.to_atom("node_#{node_id}")
    else
      node_id
    end
  end
end
