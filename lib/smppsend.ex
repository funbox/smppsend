defmodule Smppsend do

  alias SMPPEX.ESME.Sync, as: ESME
  alias SMPPEX.Pdu
  alias SMPPEX.Pdu.Factory
  alias SMPPEX.Pdu.PP

  require Logger
  use Dye

  @switches [
    bind_mode: :string,
    host: :string,
    port: :integer,
    system_id: :string,
    password: :string,
    system_type: :string,
    interface_version: :integer,
    addr_ton: :integer,
    addr_npi: :integer,
    address_range: :string,

    submit_sm: :boolean,
    service_type: :string,
    source_addr_ton: :integer,
    source_addr_npi: :integer,
    source_addr: :string,
    dest_addr_ton: :integer,
    dest_addr_npi: :integer,
    destination_addr: :string,
    esm_class: :integer,
    protocol_id: :integer,
    priority_flag: :integer,
    schedule_delivery_time: :string,
    validity_period: :string,
    registered_delivery: :integer,
    replace_if_present_flag: :integer,
    data_coding: :integer,
    sm_default_msg_id: :integer,
    short_message: :string,

    auto_split: :boolean,

    udh: :boolean,
    udh_ref: :integer,
    udh_total_parts: :integer,
    udh_part_num: :integer,

    wait_dlr: :integer,
    wait: :boolean
  ]

  @defaults [
    bind_mode: "tx",
    short_message: "",
    submit_sm: false,

    auto_split: false,

    udh: false,
    udh_ref: 0,
    udh_total_parts: 1,
    udh_part_num: 1,

    wait: false
  ]

  @required [
    :bind_mode,
    :host,
    :port,
    :system_id,
    :password,
    :submit_sm
  ]

  def main(args) do
    args
    |> parse
    |> convert_tlvs
    |> validate_unknown
    |> set_defaults
    |> validate_missing
    |> start_servers
    |> bind
    #|> send_submit_sm
    #|> wait_dlrs
    #|> wait
    # |> validate
    # |> run
  end

  defp parse(args) do
    {parsed, remaining, invalid} = OptionParser.parse(args, switches: @switches)

    if length(invalid) > 0 do
      error!(1, "Invalid options: #{invalid |> Keyword.keys |> Enum.map(&inspect/1) |> Enum.join(", ")}")
    end
    if length(remaining) > 0 do
      error!(1, "Redundant command line arguments: #{remaining |> Enum.map(&inspect/1) |> Enum.join(", ")}")
    end

    parsed
  end

  defp error!(code, desc) do
    IO.puts :stderr, ~s/#{desc}/Rd
    System.halt(code)
  end

  defp convert_tlvs(_options, _res \\ [], _tlvs \\ [])

  defp convert_tlvs([], res, tlvs), do: [{:tlvs, tlvs} | res]
  defp convert_tlvs([{:tlvs, _} | rest], res, tlvs), do: convert_tlvs(rest, res, tlvs)
  defp convert_tlvs([{k, v} | rest], res, tlvs) do
    re = ~r/^tlv_(?:(?<hex_id>x[\da-fA-F]{4})|(?<name>[a-z\_]+))_(?<value_type>s|i(?<int_value_size>1|2|4|8)|h)$/
    matches = Regex.named_captures(re, to_string(k))
    case matches do
      nil -> convert_tlvs(rest, [{k, v} | res], tlvs)
      %{"hex_id" => hex_id, "name" => name, "value_type" => value_type, "int_value_size" => int_value_size} ->
        convert_tlvs(rest, res, [{tlv_id(k, hex_id, name), tlv_value(k, value_type, int_value_size, v)} | tlvs])
    end
  end

  defp tlv_value(key, <<"i", _>>, int_value_size_s, value) do
    {int_value_size, ""} = Integer.parse(int_value_size_s)
    bit_value_size = 8 * int_value_size
    case Integer.parse(value) do
      {int, ""} -> <<int :: big-unsigned-integer-size(bit_value_size)>>
      _ -> error!(1, "Bad integer tlv value (#{inspect value}) for key #{key |> original_key}")
    end
  end
  defp tlv_value(_key, "s", _, value), do: value
  defp tlv_value(key, "h", _, value) do
    case Base.decode16(value, case: :mixed) do
      {:ok, val} -> val
      :error -> error!(1, "Bad hex tlv value (#{inspect value}) for key #{key |> original_key}")
    end
  end

  defp tlv_id(key, "", name) do
    case name |> String.to_atom |> SMPPEX.Protocol.TlvFormat.id_by_name do
      {:ok, id} -> id
      :unknown -> error!(1, "Unknown tlv name (#{name}) in key #{key |> original_key}")
    end
  end
  defp tlv_id(_key, << "x", hex_id :: binary>>, "") do
    {:ok, << int :: big-unsigned-integer-size(16) >>} = Base.decode16(hex_id, case: :mixed)
    int
  end

  defp original_key(key) do
    "--" <> Regex.replace(~r/_/, to_string(key), "-")
  end

  defp validate_unknown(opts) do
    unknown = opts |> Keyword.keys |> Enum.filter(fn(key) ->
      not Keyword.has_key?(@switches, key) and not (key == :tlvs)
    end)

    if length(unknown) > 0 do
      error!(1, "Unrecognized options: #{unknown |> Enum.map(&original_key/1) |> Enum.map(&inspect/1) |> Enum.join(", ")}")
    end

    opts
  end

  defp set_defaults(opts) do
    @defaults |> Keyword.keys |> List.foldl(opts, fn(key, opts) ->
      case Keyword.has_key?(opts, key) do
        true -> opts
        false -> Keyword.put(opts, key, @defaults[key])
      end
    end)
  end

  defp validate_missing(opts) do
    missing = @required |> Enum.filter(fn(name) -> not Keyword.has_key?(opts, name) end)

    if length(missing) > 0 do
      error!(1, "Missing options: #{missing |> Enum.map(&original_key/1) |> Enum.map(&inspect/1) |> Enum.join(", ")}")
    end

    opts
  end

  defp start_servers(opts) do
    Application.start(:ranch, :permanent)
    opts
  end

  @bind_field_names [
    :system_id,
    :password,
    :system_type,
    :interface_version,
    :addr_ton,
    :addr_npi,
    :address_range
  ]

  defp bind(opts) do
    host = opts[:host]
    port = opts[:port]

    Logger.info "Connecting to #{host}:#{port}"

    {:ok, esme} = ESME.start_link(host, port)

    Logger.info "Connected"

    bind_fields = @bind_field_names |> List.foldl(%{}, fn(key, fields) ->
      Map.put(fields, key, opts[key])
    end)
    bind = Factory.bind(bind_mode(opts[:bind_mode]), bind_fields)

    Logger.info "Binding:#{PP.format(bind)}"
    response = ESME.request(esme, bind)
    case response do
      {:ok, pdu} ->
        Logger.info("Bind response:#{PP.format(pdu)}")
        case Pdu.command_status(pdu) do
          0 ->
            Logger.info("Bound successfully")
            {esme, opts}
          status -> error!(3, "Bind failed, status: #{status}")
        end
      :timeout -> error!(3, "Bind failed, timeout")
      :stop -> error!(3, "Bind failed, esme stopped")
      {:error, error} -> error!(3, "Bind failed, error: #{inspect error}")
    end
  end

  @bind_modes %{
    "trx" => :bind_transceiver,
    "transceiver" => :bind_transceiver,
    "rx" => :bind_receiver,
    "receiver" => :bind_receiver,
    "tx" => :bind_transmitter,
    "transmitter" => :bind_transmitter
  }

  defp bind_mode(mode) do
    case Map.has_key?(@bind_modes, mode) do
      true -> @bind_modes[mode]
      false -> error!(2, "Bad bind mode: #{inspect mode}, only following modes allowed: #{@bind_modes |> Map.keys |> Enum.join(", ")}")
    end
  end

end
