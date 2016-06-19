defmodule SMPPSend.PduHelpersTest do
  use ExUnit.Case

  alias SMPPEX.Pdu

  import SMPPSend.PduHelpers

  test "bind" do
    opts = [
      system_id: "sid",
      password: "pwd",
      system_type: "conn",
      interface_version: 1,
      addr_ton: 1,
      addr_npi: 1,
      address_range: "range",
      bind_mode: "tx"
    ]

    assert {:ok, pdu} = bind(opts)

    assert Pdu.command_name(pdu) == :bind_transmitter
    assert Pdu.field(pdu, :system_id) == "sid"
    assert Pdu.field(pdu, :password) == "pwd"
    assert Pdu.field(pdu, :system_type) == "conn"
    assert Pdu.field(pdu, :interface_version) == 1
    assert Pdu.field(pdu, :addr_ton) == 1
    assert Pdu.field(pdu, :addr_npi) == 1
  end

  test "bind: bad mode" do
    opts = [
      system_id: "sid",
      password: "pwd",
      system_type: "conn",
      interface_version: 1,
      addr_ton: 1,
      addr_npi: 1,
      address_range: "range",
      bind_mode: "txx"
    ]

    assert {:error, _} = bind(opts)
  end

end
