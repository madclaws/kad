defmodule Kad do
  @moduledoc """
  Documentation for `Kad`.
  """

  # TODO: docs
  @spec start_node(Keyword.t()) :: any()
  def start_node(args) do
    DynamicSupervisor.start_child(Kad.DynamicSupervisor, {Kad.Node, args})
  end

  # TODO: docs
  @spec minikad(Keyword.t()) :: :ok
  def minikad(_args \\ []) do
    System.put_env(
      "kad_bit_space",
      "6"
    )

    System.put_env("kad_k", "2")
    :observer.start()
    start_node(is_bootstrap: true)
    start_node(node_id: 2)
    start_node(node_id: 50)
    start_node(node_id: 60)
  end

  # TODO: docs
  @spec megakad(Keyword.t()) :: :ok
  def megakad(_args \\ []) do
    System.put_env(
      "kad_bit_space",
      "160"
    )

    System.put_env("kad_k", "4")
    :observer.start()
    start_node(is_bootstrap: true)
    start_node([])
    start_node([])
    start_node([])
  end

  def connect_term() do
    Node.connect(:term1@localhost)
    Node.connect(:term2@localhost)
  end

  @spec get(atom(), any()) :: any()
  def get(node_id, key) do
    pid = :global.whereis_name(node_id)
    Kad.Node.get(pid, key)
  end

  @spec put(atom(), any(), any()) :: any()
  def put(node_id, key, val) do
    pid = :global.whereis_name(node_id)
    Kad.Node.put(pid, key, val)
  end
end
