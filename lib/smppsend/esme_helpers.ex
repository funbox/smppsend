defmodule SMPPSend.ESMEHelpers do
  alias SMPPEX.Pdu
  alias SMPPEX.Pdu.Factory
  alias SMPPEX.Pdu.PP
  alias :timer, as: Timer

  require Logger

  def connect(host, port, bind_pdu, session_opts \\ [], esme_mod \\ SMPPEX.ESME.Sync) do
    Logger.info "Connecting to #{host}:#{port}"

    case esme_mod.start_link(host, port, session_opts) do
      {:ok, esme} ->
        Logger.info "Connected"
        bind(esme, bind_pdu, esme_mod)
      {:error, reason} -> {:error, "error connecting: #{inspect reason}"}
    end
  end

  defp bind(esme, bind_pdu, esme_mod) do
    Logger.info("Binding #{PP.format(bind_pdu)}")
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


  def wait_dlrs(_esme, _message_ids, _timeout, _esme_mod \\ SMPPEX.ESME.Sync)

  def wait_dlrs(_esme, [], _timeout, _esme_mod), do: :ok
  def wait_dlrs(_esme, _message_ids, timeout, _esme_mod) when timeout <= 0, do: {:error, "timeout"}
  def wait_dlrs(esme, message_ids, timeout, esme_mod) do
    case wait_for_pdus(esme, esme_mod, timeout) do
      {_, :stop} -> {:error, "ESME stopped while waiting for dlrs"}
      {_, :timeout} -> {:error, "timeout while waiting for dlrs"}
      {time, pdus} ->
        receipted_message_ids = handle_async_results(esme, pdus)
        case message_ids -- receipted_message_ids do
          [] -> :ok
          remaining_message_ids ->
            wait_dlrs(esme, remaining_message_ids, timeout - div(time, 1000), esme_mod)
        end
    end
  end

  defp wait_for_pdus(esme, esme_mod, timeout) do
    Timer.tc(fn() ->
      esme_mod.wait_for_pdus(esme, timeout)
    end)
  end

  def wait_infinitely(esme, esme_mod \\ SMPPEX.ESME.Sync, next \\ &wait_infinitely/3)
  def wait_infinitely(esme, esme_mod, next) do
    Logger.info("Waiting...")

    case esme_mod.wait_for_pdus(esme) do
      :stop -> {:error, "esme stopped"}
      :timeout -> next.(esme, esme_mod, next)
      wait_result ->
        handle_async_results(esme, wait_result)
        next.(esme, esme_mod, next)
    end
  end

  defp handle_async_results(esme, pdus, message_ids \\ [])

  defp handle_async_results(_esme, [], message_ids), do: message_ids

  defp handle_async_results(esme, [{:pdu, pdu} | rest_pdus], message_ids) do
    Logger.info("Pdu received:#{PP.format pdu}")
    case Pdu.command_name(pdu) do
      :deliver_sm ->
        receipted_message_id = Pdu.field(pdu, :receipted_message_id)
        deliver_sm_resp(esme,pdu)
        handle_async_results(esme, rest_pdus, [ receipted_message_id | message_ids ])
      _ ->
        handle_async_results(esme, rest_pdus, message_ids)
    end
  end

  defp handle_async_results(esme, [{:resp, pdu, _original_pdu} | rest_pdus], message_ids) do
    Logger.info("Response received:#{PP.format pdu}")
    handle_async_results(esme, rest_pdus, message_ids)
  end

  defp handle_async_results(esme, [{:timeout, pdu} | rest_pdus], message_ids) do
    Logger.info("Pdu timeout:#{PP.format pdu}")
    handle_async_results(esme, rest_pdus, message_ids)
  end

  defp handle_async_results(esme, [{:ok, pdu} | rest_pdus], message_ids) do
    Logger.info("Pdu sent:#{PP.format pdu}")
    handle_async_results(esme, rest_pdus, message_ids)
  end

  defp handle_async_results(esme, [{:error, pdu, error} | rest_pdus], message_ids) do
    Logger.info("Pdu send error(#{inspect error}):#{PP.format pdu}")
    handle_async_results(esme, rest_pdus, message_ids)
  end

  def unbind(esme, esme_mod \\ SMPPEX.ESME.Sync) do
    unbind_pdu = Factory.unbind
    Logger.info("Sending unbind:#{PP.format unbind_pdu}")
    response = esme_mod.request(esme, unbind_pdu)
    case response do
      {:ok, pdu} ->
        Logger.info("Unbind resp received:#{PP.format pdu}")
        :ok
      :timeout -> {:error, "timeout"}
      :stop -> {:error, "esme stopped"}
      {:error, error} -> {:error, inspect(error)}
    end
  end

  defp deliver_sm_resp(esme, pdu) do
    resp = Factory.deliver_sm_resp |> Pdu.as_reply_to(pdu)
    SMPPEX.Session.send_pdu(esme, resp)
  end
end
