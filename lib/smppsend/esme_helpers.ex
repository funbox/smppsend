defmodule SMPPSend.ESMEHelpers do
  alias SMPPEX.Pdu
  alias SMPPEX.Pdu.PP

  require Logger

  def connect(host, port, bind_pdu, esme_mod \\ SMPPEX.ESME.Sync) do
    Logger.info "Connecting to #{host}:#{port}"

    case esme_mod.start_link(host, port) do
      {:ok, esme} ->
        Logger.info "Connected"
        bind(esme, bind_pdu, esme_mod)
      {:error, reason} -> {:error, "error connecting: #{inspect reason}"}
    end
  end

  defp bind(esme, bind_pdu, esme_mod) do
    Logger.info "Binding:#{PP.format(bind_pdu)}"

    response = esme_mod.request(esme, bind_pdu)
    case response do
      {:ok, pdu} ->
        Logger.info("Bind response:#{PP.format(pdu)}")
        case Pdu.command_status(pdu) do
          0 ->
            Logger.info("Bound successfully")
            {:ok, esme}
          status -> {:error, "bind failed, status: #{status}"}
        end
      :timeout -> {:error, "bind failed, timeout"}
      :stop -> {:error, "bind failed, esme stopped"}
      {:error, error} -> {:error, "bind failed, error: #{inspect error}"}
    end
  end


  def send_messages(_esme, _submit_sms, _esme_mod \\ SMPPEX.ESME.Sync, _message_ids \\ [])

  def send_messages(_esme, [], _esme_mod, message_ids), do: {:ok, Enum.reverse(message_ids)}

  def send_messages(esme, [submit_sm | submit_sms], esme_mod, message_ids) do
    Logger.info("Sending submit_sm#{PP.format(submit_sm)}")
    case esme_mod.request(esme, submit_sm) do
      {:ok, resp} ->
        Logger.info("Got response#{PP.format(resp)}")
        case Pdu.command_status(resp) do
          0 -> send_messages(esme, submit_sms, esme_mod, [Pdu.field(resp, :message_id) | message_ids])
          status ->
            {:error, "message status: #{status}"}
        end
      :timeout -> {:error, "timeout"}
      :stop -> {:error, "esme stopped"}
      {:error, reason} -> {:error, "error: #{inspect reason}"}
    end

  end

end
