defmodule SMPPSend.PduHelpersTest do
  use ExUnit.Case
  use Bitwise

  alias SMPPEX.Pdu

  import SMPPSend.PduHelpers

  @bind_common_opts [
    system_id: "sid",
    password: "pwd",
    system_type: "conn",
    interface_version: 1,
    addr_ton: 1,
    addr_npi: 1,
    address_range: "range"
  ]

  @submit_sm_common_opts [
    service_type: "st",
    source_addr_ton: 1,
    source_addr_npi: 2,
    source_addr: "source",
    dest_addr_ton: 3,
    dest_addr_npi: 4,
    destination_addr: "dest",
    protocol_id: 5,
    priority_flag: 6,
    schedule_delivery_time: "dt",
    validity_period: "vp",
    registered_delivery: 7,
    replace_if_present_flag: 8,
    data_coding: 9,
    sm_default_msg_id: 10
  ]

  @tlvs [{0x1234, "foo"}]

  defp check_pdu_fields(pdu, fields) do
    fields
    |> Keyword.keys()
    |> Enum.each(fn name ->
      assert fields[name] == Pdu.field(pdu, name)
    end)
  end

  defp check_pdu_tlvs(pdu, fields) do
    fields
    |> Enum.each(fn {id, value} ->
      assert value == Pdu.optional_field(pdu, id)
    end)
  end

  test "bind" do
    opts =
      @bind_common_opts ++
        [
          bind_mode: "tx"
        ]

    assert {:ok, pdu} = bind(opts)

    assert Pdu.command_name(pdu) == :bind_transmitter
    check_pdu_fields(pdu, @bind_common_opts)
  end

  test "bind: bad mode" do
    opts =
      @bind_common_opts ++
        [
          bind_mode: "txx"
        ]

    assert {:error, _} = bind(opts)
  end

  test "submit_sms: without udh" do
    opts =
      @submit_sm_common_opts ++
        [
          tlvs: @tlvs,
          short_message: "foo",
          esm_class: 0
        ]

    assert {:ok, [pdu]} = submit_sms(opts, :none)

    assert Pdu.field(pdu, :short_message) == "foo"
    assert Pdu.field(pdu, :esm_class) == 0

    check_pdu_fields(pdu, @submit_sm_common_opts)
    check_pdu_tlvs(pdu, @tlvs)
  end

  test "submit_sms: with custom udh" do
    opts =
      @submit_sm_common_opts ++
        [
          tlvs: @tlvs,
          short_message: <<100, 101>>,
          esm_class: 123,
          udh_ref: 123,
          udh_total_parts: 2,
          udh_part_num: 1
        ]

    assert {:ok, [pdu]} = submit_sms(opts, :custom_udh)

    assert Pdu.field(pdu, :short_message) == <<5, 0, 3, 123, 2, 1, 100, 101>>
    assert Pdu.field(pdu, :esm_class) == (123 ||| 64)

    check_pdu_fields(pdu, @submit_sm_common_opts)
    check_pdu_tlvs(pdu, @tlvs)
  end

  test "submit_sms: with auto_split" do
    opts =
      @submit_sm_common_opts ++
        [
          tlvs: @tlvs,
          short_message: "hellohellohellohellohellohellohello",
          esm_class: 123,
          split_max_bytes: 25,
          udh_ref: 123
        ]

    assert {:ok, [pdu1, pdu2]} = submit_sms(opts, :auto_split)

    assert Pdu.field(pdu1, :short_message) == <<5, 0, 3, 123, 2, 1>> <> "hellohellohellohell"
    assert pdu1 |> Pdu.field(:short_message) |> byte_size == 25
    assert Pdu.field(pdu1, :esm_class) == (123 ||| 64)
    check_pdu_fields(pdu1, @submit_sm_common_opts)
    check_pdu_tlvs(pdu1, @tlvs)

    assert Pdu.field(pdu2, :short_message) == <<5, 0, 3, 123, 2, 2>> <> "ohellohellohello"
    assert Pdu.field(pdu2, :esm_class) == (123 ||| 64)
    check_pdu_fields(pdu2, @submit_sm_common_opts)
    check_pdu_tlvs(pdu2, @tlvs)
  end

  test "submit_sms: udh fail" do
    opts =
      @submit_sm_common_opts ++
        [
          tlvs: @tlvs,
          short_message: "hellohellohellohellohellohellohello",
          esm_class: 123,
          split_max_bytes: 25,
          udh_ref: "foobarbazz"
        ]

    assert {:error, _} = submit_sms(opts, :auto_split)
    assert {:error, _} = submit_sms(opts, :custom_udh)
  end
end
