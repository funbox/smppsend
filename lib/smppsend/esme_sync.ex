defmodule SMPPSend.ESMESync do
  @behaviour SMPPSend.ESMEMod

  @impl SMPPSend.ESMEMod
  def start_link(host, port, opts) do
    SMPPEX.ESME.Sync.start_link(host, port, opts)
  end

  @impl SMPPSend.ESMEMod
  def request(esme, pdu) do
    SMPPEX.ESME.Sync.request(esme, pdu)
  end

  @impl SMPPSend.ESMEMod
  def pdus(esme) do
    SMPPEX.ESME.Sync.pdus(esme)
  end

  @impl SMPPSend.ESMEMod
  def wait_for_pdus(esme, timeout) do
    SMPPEX.ESME.Sync.wait_for_pdus(esme, timeout)
  end

  @impl SMPPSend.ESMEMod
  def send_pdu(esme, pdu) do
    SMPPEX.Session.send_pdu(esme, pdu)
  end
end
