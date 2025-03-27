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

  def format_bin_id(node_id_bin, bitspace) do
    String.duplicate("0", bitspace - String.length(node_id_bin)) <> node_id_bin
  end

  @spec get_common_prefix(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  def get_common_prefix(self_node, incoming_node, bitspace) do
    self_node_str = Integer.to_string(self_node, 2) |> format_bin_id(bitspace)
    incoming_node_str = Integer.to_string(incoming_node, 2) |> format_bin_id(bitspace)

    Enum.reduce_while(0..(bitspace - 1), "", fn index, bucket ->
      if String.at(self_node_str, index) == String.at(incoming_node_str, index) do
        {:cont, bucket <> String.at(self_node_str, index)}
      else
        {:halt, bucket <> String.at(incoming_node_str, index)}
      end
    end)
  end
end
