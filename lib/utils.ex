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

    #  use :binary.decode_unsigned() to convert to number
    # then can be used for creating route table.

    # hex can maybe used for readability - use :binary.encode_hex()

  end

  @doc """
  Generate an non-neg integer between a given range 0 to 2^bitspace
  """
  @spec generate_node_id(non_neg_integer()) :: non_neg_integer()
  def generate_node_id(bitspace) do
    Enum.random(1..get_max_id(bitspace))
  end

  def get_max_id(bitspace) do
    max =
      :math.pow(2, bitspace)
      |> Float.to_string()
      |> String.split(".")
      |> List.first()
      |> String.to_integer()

    max - 1
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

  @spec create_routing_table(non_neg_integer(), non_neg_integer()) :: map()
  def create_routing_table(node_id, bitspace) do
    node_id = Integer.to_string(node_id, 2)
    node_id_bin = format_bin_id(node_id, bitspace)

    Enum.reduce(1..bitspace, %{}, fn bit, table ->
      prefix = String.slice(node_id_bin, 0, bit)

      prefix = String.replace_suffix(prefix, String.last(prefix), flip_bit(String.last(prefix)))
      Map.put(table, prefix, [])
    end)
  end

  def format_bin_id(node_id_bin, bitspace) do
    String.duplicate("0", bitspace - String.length(node_id_bin)) <> node_id_bin
  end

  defp flip_bit("0"), do: "1"
  defp flip_bit("1"), do: "0"
end
