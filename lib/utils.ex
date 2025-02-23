defmodule Utils do
  @doc """
  Returns a 20byte nodeId in HEX
  """
  @spec generate_node_id :: binary()
  def generate_node_id do
    # create a random number
    # hash it with sha
    System.unique_integer([:positive]) |> to_string()
    |> then(&:crypto.hash(:sha, &1))
    |> Base.encode16(case: :lower)
  end
end
