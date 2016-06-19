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

end
