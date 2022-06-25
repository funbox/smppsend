defmodule SMPPSend.OptionHelpersTest do
  use ExUnit.Case

  import SMPPSend.OptionHelpers

  test "find_unknown" do
    assert [] == find_unknown([a: 1, b: 2], [:a, :b, :c])
    assert [:a] == find_unknown([a: 1, b: 2], [:b, :c])
  end

  test "set_defaults" do
    assert Keyword.equal?([a: :b, c: :d, e: :f], set_defaults([a: :b, e: :f], a: 123, c: :d))
  end

  test "convert_to_ucs2, ok" do
    assert {:ok, new_list} = convert_to_ucs2([a: "привет", b: "пока"], :a)
    assert Keyword.equal?([a: <<4, 63, 4, 64, 4, 56, 4, 50, 4, 53, 4, 66>>, b: "пока"], new_list)

    assert {:ok, new_list} = convert_to_ucs2([a: <<0xC2, 0xA0>>], :a)
    assert Keyword.equal?([a: <<0x00, 0xA0>>], new_list)

    assert {:ok, new_list} = convert_to_ucs2([a: <<0xE1, 0x9A, 0x80>>], :a)
    assert Keyword.equal?([a: <<0x16, 0x80>>], new_list)
  end

  test "convert_to_ucs2, error" do
    assert {:error, _} = convert_to_ucs2([a: <<231, 232>>, b: "пока"], :a)
  end

  test "decode_hex_string, ok" do
    assert {:ok, new_list} = decode_hex_string([a: "003100320033", b: "пока"], :a)
    assert Keyword.equal?([a: <<0, 49, 0, 50, 0, 51>>, b: "пока"], new_list)
  end

  test "decode_hex_string, length error" do
    assert {:error, _} = decode_hex_string([a: "123", b: "пока"], :a)
  end

  test "decode_hex_string, alphabet error" do
    assert {:error, _} = decode_hex_string([a: "hello", b: "пока"], :a)
  end
end
