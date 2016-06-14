defmodule Smppsend do

  alias SMPPEX.ESME.Sync, as: ESME
  alias SMPPEX.Pdu
  alias SMPPEX.Pdu.Factory
  alias SMPPEX.Pdu.PP
  alias SMPPEX.Protocol.CommandNames

  require Logger
  use Dye
  use Bitwise

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

    split_max_bytes: :integer,

    udh: :boolean,
    udh_ref: :integer,
    udh_total_parts: :integer,
    udh_part_num: :integer,

    ucs2: :boolean,

    wait_dlrs: :integer,
    wait: :boolean
  ]

  @defaults [
    bind_mode: "tx",
    esm_class: 0,
    short_message: "",
    submit_sm: false,

    auto_split: false,

    udh: false,
    udh_ref: 0,
    udh_total_parts: 1,
    udh_part_num: 1,

    ucs2: false,

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
    |> convert_to_ucs2
    |> start_servers
    |> bind
    |> send_messages
    |> wait_dlrs
    |> wait
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

  defp convert_to_ucs2(opts) do
    if opts[:ucs2] do
      short_message = try do
        to_ucs2(opts[:short_message])
      catch some, error ->
        error!(7, "Failed to convert short_message to ucs2: #{inspect {some, error}}")
      end

      tlvs = opts[:tlvs]
      {:ok, message_payload_id} = SMPPEX.Protocol.TlvFormat.id_by_name(:message_payload)
      new_tlvs = if tlvs[message_payload_id] do
        message_payload = try do
          to_ucs2(tlvs[message_payload_id])
        catch some, error ->
          error!(7, "Failed to convert message_payload to ucs2: #{inspect {some, error}}")
        end
        :lists.keyreplace(message_payload_id, 1, tlvs, {message_payload_id, message_payload})
      else
        tlvs
      end

      opts
        |> Keyword.put(:short_message, short_message)
        |> Keyword.put(:tlvs, new_tlvs)
    else
      opts
    end
  end

  defp to_ucs2(str) do
    str
      |> to_char_list
      |> :xmerl_ucs.to_ucs2be
      |> to_string
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

  defp fields_from_opts(field_list, opts) do
    field_list |> List.foldl(%{}, fn(key, fields) ->
      Map.put(fields, key, opts[key])
    end)
  end

  defp bind(opts) do
    host = opts[:host]
    port = opts[:port]

    Logger.info "Connecting to #{host}:#{port}"

    {:ok, esme} = ESME.start_link(host, port)

    Logger.info "Connected"

    bind_fields = fields_from_opts(@bind_field_names, opts)
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

    {esme, opts}
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

  @submit_sm_fields [
    :service_type,
    :source_addr_ton,
    :source_addr_npi,
    :source_addr,
    :dest_addr_ton,
    :dest_addr_npi,
    :destination_addr,
    :protocol_id,
    :priority_flag,
    :schedule_delivery_time,
    :validity_period,
    :registered_delivery,
    :replace_if_present_flag,
    :data_coding,
    :sm_default_msg_id
  ]

  @esm_class_gsm_udhi 0b01000000

  defp send_messages({esme, opts}) do
    message_ids = if opts[:submit_sm] do
      submit_sm_fields = fields_from_opts(@submit_sm_fields, opts)

      {esm_class, short_messages} = esm_class_and_messages(opts)

      Logger.info "Sending #{length(short_messages)} message(s)"

      {:ok, command_id} = CommandNames.id_by_name(:submit_sm)

      short_messages |> Enum.map(fn(message) ->
        mandatory = submit_sm_fields
          |> Map.put(:short_message, message)
          |> Map.put(:esm_class, esm_class)
        optional = tlvs(opts[:tlvs])
        submit_sm = Pdu.new(command_id, mandatory, optional)

        Logger.info("Sending submit_sm#{PP.format(submit_sm)}")
        case ESME.request(esme, submit_sm) do
          {:ok, resp} ->
            Logger.info("Got response#{PP.format(resp)}")
            case Pdu.command_status(resp) do
              0 -> Pdu.field(resp, :message_id)
              status ->
                error!(6, "Message submit failed, status: #{status}")
            end
          :timeout ->
            error!(6, "Message submit failed, timeout")
          :stop ->
            error!(6, "Message submit failed, esme stopped")
          {:error, reason} ->
            error!(6, "Message submit failed, error: #{inspect reason}")
        end
      end)
    else
      []
    end
    {esme, opts, message_ids}
  end

  defp esm_class_and_messages(opts) do
    if opts[:udh] && opts[:split_max_bytes] do
      error!(4, "Options --udh and --split-max-bytes can't be used together")
    end

    split_max_bytes = opts[:split_max_bytes]

    original_short_message = opts[:short_message]
    original_esm_class = opts[:esm_class]
    cond do
      opts[:udh] ->
        part_info = {
          opts[:udh_ref],
          opts[:udh_total_parts],
          opts[:udh_part_num]
        }
        {:ok, data} = SMPPEX.Pdu.Multipart.prepend_message_with_part_info(part_info, original_short_message)
        esm_class = original_esm_class ||| @esm_class_gsm_udhi
        {esm_class, [data]}
      split_max_bytes ->
        case SMPPEX.Pdu.Multipart.split_message(opts[:udh_ref], original_short_message, split_max_bytes) do
          {:ok, :split, messages} ->
            esm_class = original_esm_class ||| @esm_class_gsm_udhi
            {esm_class, messages}
          {:ok, :unsplit} ->
            {original_esm_class, [original_short_message]}
          {:error, error} ->
            error!(5, "Can't split message: #{inspect error}")
        end
      true ->
        {original_esm_class, [original_short_message]}
    end
  end

  defp tlvs(tlv_list) do
    tlv_list |> List.foldl(%{}, fn({tlv_id, tlv_value}, tlv_map) ->
      Map.put(tlv_map, tlv_id, tlv_value)
    end)
  end

  defp wait_dlrs({esme, opts, []}) do
    {esme, opts}
  end
  defp wait_dlrs({esme, opts, message_ids}) do
    if opts[:wait_dlrs] do
      wait_dlrs(esme, message_ids, opts[:wait_dlrs])
    end
    {esme, opts}
  end

  defp wait_dlrs(_esme, [], _timeout), do: Logger.info("Dlrs for all sent messages received")
  defp wait_dlrs(_esme, _message_ids, timeout) when timeout <= 0, do: error!(8, "Timeout while waiting for dlrs")
  defp wait_dlrs(esme, message_ids, timeout) do
    {t, res} = :timer.tc(fn() ->
      ESME.wait_for_pdus(esme, timeout)
    end)
    case res do
      :stop -> error!(8, "Esme stopped while waiting for dlrs")
      :timeout -> error!(8, "Timeout while waiting for dlrs")
      pdus -> handle_wait_dlr_results(esme, pdus, message_ids, timeout - div(t, 1000))
    end
  end

  defp handle_wait_dlr_results(esme, [{:pdu, pdu} | rest_pdus], message_ids, timeout) do
    Logger.info("Pdu received:#{PP.format pdu}")
    command_name = Pdu.command_name(pdu)
    if (command_name == :deliver_sm) do
      handle_wait_dlr_results(esme, rest_pdus, message_ids -- [Pdu.field(pdu, :receipted_message_id)], timeout)
    else
      handle_wait_dlr_results(esme, rest_pdus, message_ids, timeout)
    end
  end
  defp handle_wait_dlr_results(esme, [{:resp, pdu} | rest_pdus], message_ids, timeout) do
    Logger.info("Pdu received:#{PP.format pdu}")
    handle_wait_dlr_results(esme, rest_pdus, message_ids, timeout)
  end
  defp handle_wait_dlr_results(esme, [{:timeout, pdu} | rest_pdus], message_ids, timeout) do
    Logger.info("Pdu timeout:#{PP.format pdu}")
    handle_wait_dlr_results(esme, rest_pdus, message_ids, timeout)
  end
  defp handle_wait_dlr_results(esme, [{:error, pdu, error} | rest_pdus], message_ids, timeout) do
    Logger.info("Pdu error(#{inspect error}):#{PP.format pdu}")
    handle_wait_dlr_results(esme, rest_pdus, message_ids, timeout)
  end
  defp handle_wait_dlr_results(esme, [], message_ids, timeout) do
    wait_dlrs(esme, message_ids, timeout)
  end

  defp wait({esme, opts}) do
    if opts[:wait] do
      wait_infinitely(esme)
    end
  end

  defp wait_infinitely(esme) do
    Logger.info("Waiting...")

    res = ESME.wait_for_pdus(esme)
    case res do
      :stop -> error!(9, "Esme stopped")
      :timeout -> wait_infinitely(esme)
      pdus -> handle_wait_results(esme, pdus)
    end
  end

  defp handle_wait_results(esme, [{:resp, pdu} | rest_pdus]) do
    Logger.info("Pdu received:#{PP.format pdu}")
    handle_wait_results(esme, rest_pdus)
  end
  defp handle_wait_results(esme, [{:timeout, pdu} | rest_pdus]) do
    Logger.info("Pdu timeout:#{PP.format pdu}")
    handle_wait_results(esme, rest_pdus)
  end
  defp handle_wait_results(esme, [{:error, pdu, error} | rest_pdus]) do
    Logger.info("Pdu error(#{inspect error}):#{PP.format pdu}")
    handle_wait_results(esme, rest_pdus)
  end
  defp handle_wait_results(esme, []) do
    wait_infinitely(esme)
  end

end
