defmodule SMPPSend.PduHelpers do
  alias SMPPEX.Pdu
  alias SMPPEX.Pdu.Factory
  alias SMPPEX.Protocol.CommandNames

  use Bitwise

  @submit_sm_field_names [
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

  @bind_field_names [
    :system_id,
    :password,
    :system_type,
    :interface_version,
    :addr_ton,
    :addr_npi,
    :address_range
  ]

  @bind_modes %{
    "trx" => :bind_transceiver,
    "transceiver" => :bind_transceiver,
    "rx" => :bind_receiver,
    "receiver" => :bind_receiver,
    "tx" => :bind_transmitter,
    "transmitter" => :bind_transmitter
  }

  @esm_class_gsm_udhi 0b01000000

  def bind(opts) do
    case bind_mode(opts[:bind_mode]) do
      {:ok, mode} ->
        bind_fields = fields_from_opts(@bind_field_names, opts)
        {:ok, Factory.bind(mode, bind_fields)}

      {:error, _error} = error ->
        error
    end
  end

  def submit_sms(opts, udh_opts)
      when udh_opts == :custom_udh or udh_opts == :auto_split or udh_opts == :none do
    case esm_class_and_messages(opts, udh_opts) do
      {:ok, {esm_class, short_messages}} ->
        {:ok, command_id} = CommandNames.id_by_name(:submit_sm)
        submit_sm_fields = fields_from_opts(@submit_sm_field_names, opts)

        {:ok,
         short_messages
         |> Enum.map(fn message ->
           mandatory =
             submit_sm_fields
             |> Map.put(:short_message, message)
             |> Map.put(:esm_class, esm_class)

           optional = tlvs(opts[:tlvs])
           Pdu.new(command_id, mandatory, optional)
         end)}

      {:error, _error} = error ->
        error
    end
  end

  defp bind_mode(mode) do
    case Map.has_key?(@bind_modes, mode) do
      true ->
        {:ok, @bind_modes[mode]}

      false ->
        {:error,
         "Bad bind mode: #{inspect(mode)}, only following modes allowed: #{
           @bind_modes |> Map.keys() |> Enum.join(", ")
         }"}
    end
  end

  defp fields_from_opts(field_list, opts) do
    field_list
    |> List.foldl(%{}, fn key, fields ->
      Map.put(fields, key, opts[key])
    end)
  end

  defp esm_class_and_messages(opts, :none) do
    {:ok, {opts[:esm_class], [opts[:short_message]]}}
  end

  defp esm_class_and_messages(opts, :custom_udh) do
    original_short_message = opts[:short_message]
    original_esm_class = opts[:esm_class]

    part_info = {
      opts[:udh_ref],
      opts[:udh_total_parts],
      opts[:udh_part_num]
    }

    case SMPPEX.Pdu.Multipart.prepend_message_with_part_info(part_info, original_short_message) do
      {:ok, data} ->
        esm_class = original_esm_class ||| @esm_class_gsm_udhi
        {:ok, {esm_class, [data]}}

      {:error, _} = error ->
        error
    end
  end

  defp esm_class_and_messages(opts, :auto_split) do
    split_max_bytes = opts[:split_max_bytes]
    original_short_message = opts[:short_message]
    original_esm_class = opts[:esm_class]

    case SMPPEX.Pdu.Multipart.split_message(
           opts[:udh_ref],
           original_short_message,
           split_max_bytes
         ) do
      {:ok, :split, messages} ->
        esm_class = original_esm_class ||| @esm_class_gsm_udhi
        {:ok, {esm_class, messages}}

      {:ok, :unsplit} ->
        {:ok, {original_esm_class, [original_short_message]}}

      {:error, error} ->
        {:error, "Can't split message: #{inspect(error)}"}
    end
  end

  defp tlvs(nil), do: tlvs([])

  defp tlvs(tlv_list) do
    tlv_list
    |> List.foldl(%{}, fn {tlv_id, tlv_value}, tlv_map ->
      Map.put(tlv_map, tlv_id, tlv_value)
    end)
  end
end
