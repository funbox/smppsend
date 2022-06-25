defmodule SMPPSend.ESMEMod do
  alias SMPPEX.Pdu

  @callback start_link(host :: term, port :: non_neg_integer, opts :: Keyword.t()) ::
              GenServer.on_start()

  @callback request(esme :: pid, pdu :: Pdu.t()) ::
              {:ok, resp :: Pdu.t()} | :timeout | :stop | {:error, reason :: term}

  @type awaited ::
          {:pdu, pdu :: Pdu.t()}
          | {:resp, resp_pdu :: Pdu.t(), original_pdu :: Pdu.t()}
          | {:timeout, pdu :: Pdu.t()}
          | {:error, pdu :: Pdu.t(), reason :: any}

  @callback pdus(esme :: pid) :: [awaited]

  @callback wait_for_pdus(esme :: pid, timeout()) :: [awaited] | :timeout | :stop

  @callback send_pdu(session :: pid, Pdu.t()) :: :ok
end
