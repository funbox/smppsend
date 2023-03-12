defmodule SMPPSend do
  require Logger
  use Dye

  @switches [
    help: :boolean,
    version: :boolean,
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
    binary: :boolean,
    gsm: :boolean,
    latin1: :boolean,
    wait_dlrs: :integer,
    wait: :boolean,
    tls: :boolean,
    sn: :integer
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
    binary: false,
    latin1: false,
    gsm: false,
    wait: false,
    sn: 0
  ]

  @required [
    :bind_mode,
    :host,
    :port,
    :system_id,
    :password,
    :submit_sm
  ]

  @exit_code_ok 0
  @exit_code_error 1

  def main(args) do
    code =
      chain(args, [
        &parse/1,
        &convert_tlvs/1,
        &validate_unknown/1,
        &set_defaults/1,
        &show_help/1,
        &show_version/1,
        &validate_missing/1,
        &decode_hex_string/1,
        &encode/1,
        &trap_exit/1,
        &bind/1,
        &send_messages/1,
        &wait_dlrs/1,
        &wait/1,
        &unbind/1
      ])

    Logger.flush()
    System.halt(code)
  end

  ## For Burrito
  def start(_, _) do
    case Application.get_env(:smppsend, :main_in_app_start, false) do
      true ->
        Burrito.Util.Args.get_arguments()
        |> main()
      false ->
        Supervisor.start_link([], strategy: :one_for_one)
    end
  end

  defp parse(args) do
    {parsed, remaining, invalid} =
      OptionParser.parse(args, switches: @switches, allow_nonexistent_atoms: true)

    cond do
      length(invalid) > 0 ->
        {:error, "Invalid options: #{format_keys(invalid)}"}

      length(remaining) > 0 ->
        {:error, "Redundant command line arguments: #{format_keys(remaining)}"}

      true ->
        {:ok, parsed}
    end
  end

  defp convert_tlvs(opts) do
    case SMPPSend.TlvParser.convert_tlvs(opts) do
      {:ok, opts} ->
        {:ok, opts}

      {:error, message, key} ->
        {:error, "Error parsing tlv option #{format_keys(key)}: #{message}"}
    end
  end

  defp validate_unknown(opts) do
    case SMPPSend.OptionHelpers.find_unknown(opts, [:tlvs | @switches |> Keyword.keys()]) do
      [] -> {:ok, opts}
      unknown -> {:error, "Unrecognized options: #{format_keys(unknown)}"}
    end
  end

  defp set_defaults(opts) do
    {:ok, SMPPSend.OptionHelpers.set_defaults(opts, @defaults)}
  end

  defp validate_missing(opts) do
    case SMPPSend.OptionHelpers.find_missing(opts, @required) do
      [] -> {:ok, opts}
      missing -> {:error, "Missing options: #{format_keys(missing)}"}
    end
  end

  defp show_help(opts) do
    if opts[:help] do
      IO.puts(SMPPSend.Usage.help())
      :exit
    else
      {:ok, opts}
    end
  end

  defp show_version(opts) do
    if opts[:version] do
      IO.puts(SMPPSend.Version.version())
      :exit
    else
      {:ok, opts}
    end
  end

  defp decode_hex_string(opts) do
    if opts[:binary] do
      case SMPPSend.OptionHelpers.decode_hex_string(opts, :short_message) do
        {:ok, new_opts} ->
          tlvs = opts[:tlvs]
          {:ok, message_payload_id} = SMPPEX.Protocol.TlvFormat.id_by_name(:message_payload)

          case SMPPSend.OptionHelpers.decode_hex_string(tlvs, message_payload_id) do
            {:ok, new_tlvs} -> {:ok, Keyword.put(new_opts, :tlvs, new_tlvs)}
            {:error, error} -> {:error, "Failed to decode message_payload: #{error}"}
          end

        {:error, error} ->
          {:error, "Failed to decode short_message: #{error}"}
      end
    else
      {:ok, opts}
    end
  end

  defp encoding_function(opts) do
    cond do
      opts[:ucs2] -> {:ucs2, &SMPPSend.OptionHelpers.convert_to_ucs2/2}
      opts[:gsm] -> {:gsm, &SMPPSend.OptionHelpers.convert_to_gsm/2}
      opts[:latin1] -> {:latin1, &SMPPSend.OptionHelpers.convert_to_latin1/2}
      true -> {:noenc, fn opts, _ -> {:ok, opts} end}
    end
  end

  defp encode(opts) do
    {encoding_name, encoding_fn} = encoding_function(opts)

    case encoding_fn.(opts, :short_message) do
      {:ok, new_opts} ->
        tlvs = opts[:tlvs]
        {:ok, message_payload_id} = SMPPEX.Protocol.TlvFormat.id_by_name(:message_payload)

        case encoding_fn.(tlvs, message_payload_id) do
          {:ok, new_tlvs} ->
            {:ok, Keyword.put(new_opts, :tlvs, new_tlvs)}

          {:error, error} ->
            {:error, "Failed to convert message_payload to #{encoding_name}: #{error}"}
        end

      {:error, error} ->
        {:error, "Failed to convert short_message to #{encoding_name}: #{error}"}
    end
  end

  defp trap_exit(opts) do
    Process.flag(:trap_exit, true)
    {:ok, opts}
  end

  defp bind(opts) do
    host = opts[:host]
    port = opts[:port]

    case SMPPSend.PduHelpers.bind(opts) do
      {:ok, bind} ->
        case SMPPSend.ESMEHelpers.connect(host, port, bind, session_opts(opts)) do
          {:ok, esme} -> {:ok, {esme, opts}}
          {:error, error} -> {:error, "Connecting SMSC failed: #{inspect(error)}"}
        end

      {:error, _error} = error ->
        error
    end
  end

  defp session_opts(opts) do
    session_opts = []

    session_opts
    |> Keyword.put(:transport, session_transport(opts))
    |> Keyword.put(:esme_opts, esme_opts(opts))
  end

  defp esme_opts(opts) do
    esme_opts = []

    Keyword.put(esme_opts, :sequence_number, Keyword.get(opts, :sn))
  end

  defp session_transport(opts) do
    if opts[:tls] do
      :ranch_ssl
    else
      :ranch_tcp
    end
  end

  defp send_messages({esme, opts}) do
    if opts[:submit_sm] do
      if opts[:udh] && opts[:split_max_bytes] do
        {:error, "Options --udh and --split-max-bytes can't be used together"}
      else
        submit_sms =
          cond do
            opts[:udh] -> SMPPSend.PduHelpers.submit_sms(opts, :custom_udh)
            opts[:split_max_bytes] -> SMPPSend.PduHelpers.submit_sms(opts, :auto_split)
            true -> SMPPSend.PduHelpers.submit_sms(opts, :none)
          end

        case submit_sms do
          {:ok, pdus} ->
            case SMPPSend.ESMEHelpers.send_messages(esme, pdus) do
              {:ok, message_ids} -> {:ok, {esme, opts, message_ids}}
              {:error, error} -> {:error, "Message submit failed, #{error}"}
            end

          {:error, _error} = error ->
            error
        end
      end
    else
      {:ok, {esme, opts, []}}
    end
  end

  defp wait_dlrs({esme, opts, message_ids}) do
    if opts[:wait_dlrs] do
      case SMPPSend.ESMEHelpers.wait_dlrs(esme, message_ids, opts[:wait_dlrs]) do
        :ok ->
          Logger.info("Dlrs for all sent messages received")
          {:ok, {esme, opts}}

        {:error, error} ->
          {:error, "Waiting dlrs failed: #{error}"}
      end
    else
      {:ok, {esme, opts}}
    end
  end

  defp wait({esme, opts}) do
    if opts[:wait] do
      SMPPSend.ESMEHelpers.wait_infinitely(esme)
    else
      {:ok, {esme, opts}}
    end
  end

  def unbind({esme, _opts}) do
    case SMPPSend.ESMEHelpers.unbind(esme) do
      :ok -> :exit
      {:error, error} -> {:error, "Unbind failed: #{error}"}
    end
  end

  defp format_keys(keys) when not is_list(keys), do: format_keys([keys])

  defp format_keys(keys) do
    keys |> Enum.map(&original_key/1) |> Enum.map(&inspect/1) |> Enum.join(", ")
  end

  defp original_key({key, _}), do: to_string(key)
  defp original_key(key) when is_binary(key), do: key

  defp original_key(key) do
    key_s = to_string(key)

    prefix =
      case String.starts_with?(key_s, "--") do
        true -> ""
        false -> "--"
      end

    prefix <> Regex.replace(~r/_/, key_s, "-")
  end

  defp chain(arg, [fun | funs]) do
    case fun.(arg) do
      {:ok, res} ->
        chain(res, funs)

      {:error, error} ->
        IO.puts(:stderr, ~s/#{error}/Rd)
        @exit_code_error

      :exit ->
        @exit_code_ok
    end
  end

  defp chain(_, []), do: @exit_code_ok
end
