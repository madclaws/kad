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
  @spec to_hex(binary()) :: binary()
  def to_hex(node_id) do
    :binary.encode_hex(node_id)
  end

  @spec find_distance(binary(), binary()) :: integer()
  def find_distance(id1, id2) do
    :crypto.exor(id1, id2)
    |> :binary.decode_unsigned(:little)
  end
end
