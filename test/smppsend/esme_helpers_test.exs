defmodule SMPPSend.ESMEHelpersTest do
  use ExUnit.Case

  alias :doppler, as: Doppler
  alias :timer, as: Timer
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

  test "connect fail" do

    ref = make_ref
    esme_mod = Doppler.start(ref)

    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    Doppler.def(esme_mod, :start_link, fn(ref, _, _) ->
      {{:error, :econnrefused}, ref}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, esme_mod)

  end

  test "connect: bind fail" do

    ref = make_ref
    esme_mod = Doppler.start(ref)

    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    Doppler.def(esme_mod, :start_link, fn(ref, _, _) ->
      {{:ok, {:esme, ref}}, ref}
    end)
    Doppler.def(esme_mod, :request, fn(ref, _, _) ->
      resp = Factory.bind_transmitter_resp(1)
      {{:ok, resp}, ref}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, esme_mod)

  end

  test "connect: bind timeout" do

    ref = make_ref
    esme_mod = Doppler.start(ref)

    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    Doppler.def(esme_mod, :start_link, fn(ref, _, _) ->
      {{:ok, {:esme, ref}}, ref}
    end)
    Doppler.def(esme_mod, :request, fn(ref, _, _) ->
      {:timeout, ref}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, esme_mod)

  end

  test "connect: bind error" do

    ref = make_ref
    esme_mod = Doppler.start(ref)

    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    Doppler.def(esme_mod, :start_link, fn(ref, _, _) ->
      {{:ok, {:esme, ref}}, ref}
    end)
    Doppler.def(esme_mod, :request, fn(ref, _, _) ->
      {{:error, "err"}, ref}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, esme_mod)

  end

  test "connect: server close" do

    ref = make_ref
    esme_mod = Doppler.start(ref)

    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    Doppler.def(esme_mod, :start_link, fn(ref, _, _) ->
      {{:ok, {:esme, ref}}, ref}
    end)
    Doppler.def(esme_mod, :request, fn(ref, _, _) ->
      {:stop, ref}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, esme_mod)

  end

  test "send_messages" do

    esme_mod = Doppler.start(["1", "2"])

    submit_sm1 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")
    submit_sm2 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello2")

    Doppler.def(esme_mod, :request, fn([message_id | message_ids], :esme, _submit_sm) ->
      resp = Factory.submit_sm_resp(0, message_id)
      {{:ok, resp}, message_ids}
    end)

    assert {:ok, ["1", "2"]} == ESMEHelpers.send_messages(:esme, [submit_sm1, submit_sm2], esme_mod)

  end

  test "send_messages: fail" do

    esme_mod = Doppler.start([{"1",0}, {"2",1}])

    submit_sm1 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")
    submit_sm2 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello2")

    Doppler.def(esme_mod, :request, fn([{message_id, command_status} | message_ids], :esme, _submit_sm) ->
      resp = Factory.submit_sm_resp(command_status, message_id)
      {{:ok, resp}, message_ids}
    end)

    assert {:error, _} = ESMEHelpers.send_messages(:esme, [submit_sm1, submit_sm2], esme_mod)

  end

  test "wait_dlrs: empty" do

    assert :ok == ESMEHelpers.wait_dlrs(:esme, [], 10)

  end

  test "wait_dlrs: success" do

    message_ids = ["1", "2"]

    esme_mod = Doppler.start(message_ids)

    Doppler.def(esme_mod, :wait_for_pdus, fn([message_id | rest_message_ids], :esme, _timeout) ->
      dlr = Factory.delivery_report(message_id, {"from", 1, 1}, {"to", 1, 1})
      {[{:pdu, dlr}], rest_message_ids}
    end)

    assert :ok = ESMEHelpers.wait_dlrs(:esme, message_ids, 10, esme_mod)

  end

  test "wait_dlrs: timeout" do

    message_ids = [{"1", 10}, {"2", 10}]

    esme_mod = Doppler.start(message_ids)

    Doppler.def(esme_mod, :wait_for_pdus, fn([{message_id, time_to_sleep} | rest_message_ids], :esme, _timeout) ->
      dlr = Factory.delivery_report(message_id, {"from", 1, 1}, {"to", 1, 1})
      Timer.sleep(time_to_sleep)
      {[{:pdu, dlr}], rest_message_ids}
    end)

    assert {:error, _} = ESMEHelpers.wait_dlrs(:esme, message_ids, 15, esme_mod)

  end

  test "wait_dlrs: mixed wait results" do

    message_ids = ["1", "2"]

    esme_mod = Doppler.start(message_ids)

    Doppler.def(esme_mod, :wait_for_pdus, fn([message_id | rest_message_ids], :esme, _timeout) ->
      dlr = {:pdu, Factory.delivery_report(message_id, {"from", 1, 1}, {"to", 1, 1})}
      resp = {:resp, Factory.enquire_link_resp}
      error = {:error, Factory.enquire_link, "oops"}
      timeout = {:timeout, Factory.enquire_link}
      {[resp, error, timeout, dlr], rest_message_ids}
    end)

    assert :ok = ESMEHelpers.wait_dlrs(:esme, message_ids, 10, esme_mod)

  end
end
