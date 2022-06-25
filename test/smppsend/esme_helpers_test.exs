defmodule SMPPSend.ESMEHelpersTest do
  use ExUnit.Case

  alias :timer, as: Timer
  alias SMPPEX.Pdu
  alias SMPPEX.Pdu.Factory
  alias SMPPSend.ESMEHelpers

  test "connect" do
    ref = make_ref()
    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    MockESMESync
    |> Mox.stub(:start_link, fn passed_host, passed_port, [] ->
      assert host == passed_host
      assert port == passed_port
      {:ok, {:esme, ref}}
    end)
    |> Mox.stub(:request, fn {:esme, esme_ref}, passed_bind_pdu ->
      assert ref == esme_ref
      assert bind_pdu == passed_bind_pdu
      resp = Factory.bind_transmitter_resp(0, "system_id1")
      {:ok, resp}
    end)
    |> Mox.stub(:pdus, fn _ ->
      []
    end)

    assert {:ok, {:esme, ref}} == ESMEHelpers.connect(host, port, bind_pdu, [], MockESMESync)
  end

  test "connect fail" do
    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    MockESMESync
    |> Mox.stub(:start_link, fn _, _, _ ->
      {:error, :econnrefused}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, [], MockESMESync)
  end

  test "connect: bind fail" do
    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    MockESMESync
    |> Mox.stub(:start_link, fn _, _, _ ->
      {:ok, :esme}
    end)
    |> Mox.stub(:request, fn _, _ ->
      resp = Factory.bind_transmitter_resp(1)
      {:ok, resp}
    end)
    |> Mox.stub(:pdus, fn _ ->
      []
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, [], MockESMESync)
  end

  test "connect: bind timeout" do
    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    MockESMESync
    |> Mox.stub(:start_link, fn _, _, _ ->
      {:ok, :esme}
    end)
    |> Mox.stub(:request, fn _, _ ->
      :timeout
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, [], MockESMESync)
  end

  test "connect: bind error" do
    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    MockESMESync
    |> Mox.stub(:start_link, fn _, _, _ ->
      {:ok, :esme}
    end)
    |> Mox.stub(:request, fn _, _ ->
      {:error, "err"}
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, [], MockESMESync)
  end

  test "connect: server close" do
    bind_pdu = Factory.bind_transmitter("system_id", "password")
    host = "somehost"
    port = 12345

    MockESMESync
    |> Mox.stub(:start_link, fn _, _, _ ->
      {:ok, :esme}
    end)
    |> Mox.stub(:request, fn _, _ ->
      :stop
    end)

    assert {:error, _} = ESMEHelpers.connect(host, port, bind_pdu, [], MockESMESync)
  end

  test "send_messages" do
    pid = SpawnList.start_link(["1", "2"])

    submit_sm1 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")
    submit_sm2 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello2")

    MockESMESync
    |> Mox.stub(:request, fn :esme, _submit_sm ->
      message_id = SpawnList.shift(pid)
      resp = Factory.submit_sm_resp(0, message_id)
      {:ok, resp}
    end)
    |> Mox.stub(:pdus, fn :esme ->
      []
    end)

    assert {:ok, ["1", "2"]} ==
             ESMEHelpers.send_messages(:esme, [submit_sm1, submit_sm2], MockESMESync)
  end

  test "send_messages: fail" do
    pid = SpawnList.start_link([{"1", 0}, {"2", 1}])

    submit_sm1 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")
    submit_sm2 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello2")

    MockESMESync
    |> Mox.stub(:request, fn :esme, _submit_sm ->
      {message_id, command_status} = SpawnList.shift(pid)
      resp = Factory.submit_sm_resp(command_status, message_id)
      {:ok, resp}
    end)
    |> Mox.stub(:pdus, fn :esme ->
      []
    end)

    assert {:error, _} = ESMEHelpers.send_messages(:esme, [submit_sm1, submit_sm2], MockESMESync)
  end

  test "wait_dlrs: empty" do
    assert :ok == ESMEHelpers.wait_dlrs(:esme, [], 10)
  end

  test "wait_dlrs: success" do
    submit_sm1 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")
    submit_sm2 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello2")
    message_ids = ["1", "2"]

    pid = SpawnList.start_link(message_ids)

    MockESMESync
    |> Mox.stub(:wait_for_pdus, fn :esme, _timeout ->
      message_id = SpawnList.shift(pid)
      dlr = Factory.delivery_report(message_id, {"from", 1, 1}, {"to", 1, 1})
      [{:ok, submit_sm1}, {:ok, submit_sm2}, {:pdu, dlr}]
    end)
    |> Mox.stub(:send_pdu, fn :esme, _pdu ->
      :ok
    end)

    assert :ok = ESMEHelpers.wait_dlrs(:esme, message_ids, 10, MockESMESync)
  end

  test "wait_dlrs: timeout" do
    submit_sm1 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")
    submit_sm2 = Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello2")
    message_ids = [{"1", 10}, {"2", 10}]

    pid = SpawnList.start_link(message_ids)

    MockESMESync
    |> Mox.stub(:wait_for_pdus, fn :esme, _timeout ->
      {message_id, time_to_sleep} = SpawnList.shift(pid)
      dlr = Factory.delivery_report(message_id, {"from", 1, 1}, {"to", 1, 1})
      Timer.sleep(time_to_sleep)
      [{:ok, submit_sm1}, {:ok, submit_sm2}, {:pdu, dlr}]
    end)
    |> Mox.stub(:send_pdu, fn :esme, _pdu ->
      :ok
    end)

    assert {:error, _} = ESMEHelpers.wait_dlrs(:esme, message_ids, 15, MockESMESync)
  end

  test "wait_dlrs: mixed wait results" do
    message_ids = ["1", "2"]

    pid = SpawnList.start_link(message_ids)

    MockESMESync
    |> Mox.stub(:wait_for_pdus, fn :esme, _timeout ->
      message_id = SpawnList.shift(pid)
      ok = {:ok, Factory.submit_sm({"from", 1, 1}, {"to", 1, 1}, "hello1")}
      dlr = {:pdu, Factory.delivery_report(message_id, {"from", 1, 1}, {"to", 1, 1})}
      resp = {:resp, Factory.enquire_link_resp(), Factory.enquire_link()}
      error = {:error, Factory.enquire_link(), "oops"}
      timeout = {:timeout, Factory.enquire_link()}
      [ok, resp, error, timeout, dlr]
    end)
    |> Mox.stub(:send_pdu, fn :esme, _pdu ->
      :ok
    end)

    assert :ok = ESMEHelpers.wait_dlrs(:esme, message_ids, 10, MockESMESync)
  end

  test "wait_infinitely, ok" do
    next = fn _, _, _ -> :ok end

    MockESMESync
    |> Mox.stub(:wait_for_pdus, fn :esme, _timeout ->
      dlr = {:pdu, Factory.delivery_report("message_id", {"from", 1, 1}, {"to", 1, 1})}
      resp = {:resp, Factory.enquire_link_resp(), Factory.enquire_link()}
      error = {:error, Factory.enquire_link(), "oops"}
      timeout = {:timeout, Factory.enquire_link()}
      [resp, error, timeout, dlr]
    end)
    |> Mox.stub(:send_pdu, fn :esme, _pdu ->
      :ok
    end)

    assert :ok = ESMEHelpers.wait_infinitely(:esme, MockESMESync, next)
  end

  test "wait_infinitely, stop" do
    next = fn _, _, _ -> :ok end

    MockESMESync
    |> Mox.stub(:wait_for_pdus, fn :esme, _timeout ->
      :stop
    end)

    assert {:error, _} = ESMEHelpers.wait_infinitely(:esme, MockESMESync, next)
  end

  test "wait_infinitely, timeout" do
    next = fn _, _, _ -> :ok end

    MockESMESync
    |> Mox.stub(:wait_for_pdus, fn :esme, _timeout ->
      :timeout
    end)

    assert :ok = ESMEHelpers.wait_infinitely(:esme, MockESMESync, next)
  end

  test "unbind, ok" do
    MockESMESync
    |> Mox.stub(:request, fn :esme, unbind_pdu ->
      assert Pdu.command_name(unbind_pdu) == :unbind
      {:ok, Factory.unbind_resp()}
    end)

    assert :ok = ESMEHelpers.unbind(:esme, MockESMESync)
  end

  test "unbind, timeout" do
    MockESMESync
    |> Mox.stub(:request, fn :esme, unbind_pdu ->
      assert Pdu.command_name(unbind_pdu) == :unbind
      :timeout
    end)

    assert {:error, _} = ESMEHelpers.unbind(:esme, MockESMESync)
  end

  test "unbind, stop" do
    MockESMESync
    |> Mox.stub(:request, fn :esme, unbind_pdu ->
      assert Pdu.command_name(unbind_pdu) == :unbind
      :stop
    end)

    assert {:error, _} = ESMEHelpers.unbind(:esme, MockESMESync)
  end

  test "unbind, error" do
    MockESMESync
    |> Mox.stub(:request, fn :esme, unbind_pdu ->
      assert Pdu.command_name(unbind_pdu) == :unbind
      {:error, :ooops}
    end)

    assert {:error, _} = ESMEHelpers.unbind(:esme, MockESMESync)
  end
end
