defmodule SMPPSend.TlvParserTest do
  use ExUnit.Case

  import SMPPSend.TlvParser

  test "convert_tlvs: removing old :tlvs key if present" do
    assert {:ok, [tlvs: []]} = convert_tlvs(tlvs: :foo)
  end

  test "convert_tlvs: preserving non-tlv fields" do
    assert {:ok, [tlvs: [], foo: :bar]} = convert_tlvs(foo: :bar, tlvs: :foo)
  end

  test "convert_tlvs: hex hame" do
    assert {:ok, [tlvs: [{0x1234, "foo"}]]} = convert_tlvs([{"tlv_x1234_s", "foo"}])
  end

  test "convert_tlvs: symbolic name" do
    assert {:ok, [tlvs: [{0x0424, "foo"}]]} = convert_tlvs([{"tlv_message_payload_s", "foo"}])
  end

  test "convert_tlvs: bad name" do
    assert {:error, _, "tlv_messssage_payload_s"} =
             convert_tlvs([{"tlv_messssage_payload_s", "foo"}])
  end

  test "convert_tlvs: integer value" do
    assert {:ok, [tlvs: [{0x1234, 1}]]} = convert_tlvs([{"tlv_x1234_i1", "1"}])
    assert {:ok, [tlvs: [{0x1234, 1}]]} = convert_tlvs([{"tlv_x1234_i2", "1"}])
    assert {:ok, [tlvs: [{0x1234, 1}]]} = convert_tlvs([{"tlv_x1234_i4", "1"}])
    assert {:ok, [tlvs: [{0x1234, 1}]]} = convert_tlvs([{"tlv_x1234_i8", "1"}])

    assert {:error, _, _} = convert_tlvs([{"tlv_x1234_i1", "256"}])
    assert {:error, _, _} = convert_tlvs([{"tlv_x1234_i2", "65536"}])
    assert {:error, _, _} = convert_tlvs([{"tlv_x1234_i4", "4294967296"}])
    assert {:error, _, _} = convert_tlvs([{"tlv_x1234_i8", "18446744073709551616"}])
  end

  test "convert_tlvs: bad integer value" do
    assert {:error, _, "tlv_x1234_i1"} = convert_tlvs([{"tlv_x1234_i1", "123bad"}])
  end

  test "convert_tlvs: hex value" do
    assert {:ok, [tlvs: [{0x1234, "Hello world!"}]]} =
             convert_tlvs([{"tlv_x1234_h", "48656C6C6F20776F726C6421"}])
  end

  test "convert_tlvs: bad hex value" do
    assert {:error, _, "tlv_x1234_h"} = convert_tlvs([{"tlv_x1234_h", "abcdefg"}])
  end

  test "convert_tlvs: string value" do
    assert {:ok, [tlvs: [{0x1234, "Hello world!"}]]} =
             convert_tlvs([{"tlv_x1234_s", "Hello world!"}])
  end
end
