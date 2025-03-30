defmodule Utils do
  @doc """
  Generate an non-neg integer between a given range 0 to 2^bitspace
  OR returns a 20byte nodeId, if bitspace is 160
  """
  @spec generate_node_id(non_neg_integer()) :: non_neg_integer()
  def generate_node_id(6) do
    Enum.random(1..get_max_id(6))
  end

  def generate_node_id(160) do
    # create a random 160 sha
    :crypto.hash(:sha, :crypto.strong_rand_bytes(20))
    |> :binary.encode_hex(:lowercase)
  end

  @spec generate_key_id(any()) :: binary()
  def generate_key_id(key) do
    :crypto.hash(:sha, :erlang.term_to_binary(key))
    |> :binary.encode_hex(:lowercase)
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

  @spec find_distance(binary() | non_neg_integer(), binary() | non_neg_integer()) :: integer()
  def find_distance(<<_::binary>> = id1, <<_::binary>> = id2) do
    :crypto.exor(id1, id2)
    |> :binary.decode_unsigned(:little)
  end

  def find_distance(id1, id2) do
    Bitwise.bxor(id1, id2)
  end

  def format_bin_id(node_id_bin, bitspace) do
    String.duplicate("0", bitspace - String.length(node_id_bin)) <> node_id_bin
  end

  @spec get_common_prefix(
          non_neg_integer() | <<_::320>>,
          non_neg_integer() | <<_::320>>,
          non_neg_integer()
        ) :: String.t()
  def get_common_prefix(<<_::320>> = self_node, <<_::320>> = incoming_node, bitspace) do
    self_node_str =
      :binary.decode_hex(self_node)
      |> :binary.decode_unsigned(:little)
      |> Integer.to_string(2)
      |> format_bin_id(bitspace)

    incoming_node_str =
      :binary.decode_hex(incoming_node)
      |> :binary.decode_unsigned(:little)
      |> Integer.to_string(2)
      |> format_bin_id(bitspace)

    calc_common_prefix(self_node_str, incoming_node_str, bitspace)
  end

  def get_common_prefix(self_node, incoming_node, bitspace) do
    self_node_str = Integer.to_string(self_node, 2) |> format_bin_id(bitspace)
    incoming_node_str = Integer.to_string(incoming_node, 2) |> format_bin_id(bitspace)
    calc_common_prefix(self_node_str, incoming_node_str, bitspace)
  end

  @spec calc_common_prefix(String.t(), String.t(), non_neg_integer()) :: String.t()
  defp calc_common_prefix(self_node, incoming_node, bitspace) do
    Enum.reduce_while(0..(bitspace - 1), "", fn index, bucket ->
      if String.at(self_node, index) == String.at(incoming_node, index) do
        {:cont, bucket <> String.at(self_node, index)}
      else
        {:halt, bucket <> String.at(incoming_node, index)}
      end
    end)
  end
end
