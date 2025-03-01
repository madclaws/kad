defmodule Kademlia.Node do
  @moduledoc """
  Represents a real-word computer/node
  """

  @default_k 2
  @default_bitspace 6
  @default_a 3
  use GenServer
  require Logger

  @doc """
  Pass is_bootstrap: true for node to be acting as bootstrapped node
  """
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def get_id(pid) do
    :sys.get_state(pid).info |> elem(1)
  end

  def get_routing_table(pid) do
    :sys.get_state(pid).routing_table
  end

  def init(args) do
    {:ok, create_initial_state(args)}
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
    Logger.info("Routing table\n #{inspect(routing_table)}")

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
