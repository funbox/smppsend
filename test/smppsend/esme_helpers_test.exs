defmodule SMPPSend.ESMEHelpersTest do
  use ExUnit.Case

  alias :doppler, as: Doppler
  alias SMPPEX.Pdu.Factory
  alias SMPPSend.ESMEHelpers


  test "connect" do

    ref = make_ref
    esme_mod = Doppler.start(ref)

    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    Doppler.def(esme_mod, :start_link, fn(ref, passed_host, passed_port) ->
      assert host == passed_host
      assert port == passed_port
      {{:ok, {:esme, ref}}, ref}
    end)
    Doppler.def(esme_mod, :request, fn(ref, {:esme, esme_ref}, passed_bind_pdu) ->
      assert ref == esme_ref
      assert bind_pdu == passed_bind_pdu
      resp = Factory.bind_transmitter_resp(0, "system_id1")
      {{:ok, resp}, ref}
    end)

    assert {:ok, {:esme, ref}} == ESMEHelpers.connect(host, port, bind_pdu, esme_mod)

  end
end
