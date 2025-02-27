defmodule Utils do
  @doc """
  Returns a 20byte nodeId
  """
  @spec generate_node_id :: binary()
  def generate_node_id do
    # create a random number
    # hash it with sha
    System.unique_integer([:positive])
    |> to_string()
    |> then(&:crypto.hash(:sha, &1))

    # |> Base.encode16(case: :lower)
  end

  @doc """
  Convert the 20byte nodeId to hex

  When converting the size becomes double because for each byte is represented with 2 hexdecimal digits
  """
  @spec to_hex(String.t()) :: binary()
  def to_hex(node_id) do
    Base.encode16(node_id, case: :lower)
  end
end
