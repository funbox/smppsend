defmodule SMPPSend.TlvParser do
  use Bitwise

  @tlv_re ~r/^tlv_(?:(?<hex_id>x[\da-fA-F]{4})|(?<name>[a-z\_]+))_(?<value_type>s|i(?<int_value_size>1|2|4|8)|h)$/

  def convert_tlvs(_options, _res \\ [], _tlvs \\ [])

  def convert_tlvs([], res, tlvs), do: {:ok, [{:tlvs, Enum.reverse(tlvs)} | Enum.reverse(res)]}
  def convert_tlvs([{:tlvs, _} | rest], res, tlvs), do: convert_tlvs(rest, res, tlvs)

  def convert_tlvs([{key, value} | rest], res, tlvs) do
    matches = Regex.named_captures(@tlv_re, to_string(key))

    case matches do
      nil ->
        convert_tlvs(rest, [{key, value} | res], tlvs)

      %{
        "hex_id" => hex_id,
        "name" => name,
        "value_type" => value_type,
        "int_value_size" => int_value_size
      } ->
        case tlv_id(hex_id, name) do
          {:ok, tlv_id} ->
            case tlv_value(value_type, int_value_size, value) do
              {:ok, tlv_value} -> convert_tlvs(rest, res, [{tlv_id, tlv_value} | tlvs])
              {:error, error} -> {:error, error, key}
            end

          {:error, error} ->
            {:error, error, key}
        end
    end
  end

  defp tlv_value(<<"i", _>>, int_value_size_s, value) do
    {int_value_size, ""} = Integer.parse(int_value_size_s)
    bit_value_size = 8 * int_value_size
    max_val = 1 <<< bit_value_size

    case Integer.parse(value) do
      {int, ""} ->
        if int < 0 or int >= max_val do
          {:error, "bad integer value: #{int}, is expected to be between 0 and #{max_val - 1}"}
        else
          {:ok, int}
        end

      _ ->
        {:error, "bad integer tlv value (#{inspect(value)})"}
    end
  end

  defp tlv_value("s", _, value), do: {:ok, value}

  defp tlv_value("h", _, value) do
    case Base.decode16(value, case: :mixed) do
      {:ok, val} -> {:ok, val}
      :error -> {:error, "bad hex tlv value (#{inspect(value)})"}
    end
  end

  defp tlv_id("", name) do
    case name |> String.to_atom() |> SMPPEX.Protocol.TlvFormat.id_by_name() do
      {:ok, id} -> {:ok, id}
      :unknown -> {:error, "unknown tlv name (#{name})"}
    end
  end

  defp tlv_id(<<"x", hex_id::binary>>, "") do
    {:ok, <<int::big-unsigned-integer-size(16)>>} = Base.decode16(hex_id, case: :mixed)
    {:ok, int}
  end
end
