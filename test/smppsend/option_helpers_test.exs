defmodule SMPPSend.OptionHelpersTest do
  use ExUnit.Case

  import SMPPSend.OptionHelpers

  test "find_unknown" do
    assert [] == find_unknown([a: 1, b: 2], [:a, :b, :c])
    assert [:a] == find_unknown([a: 1, b: 2], [:b, :c])
  end

  test "set_defaults" do
    assert Keyword.equal?([a: :b, c: :d, e: :f], set_defaults([a: :b, e: :f], [a: 123, c: :d]))
  end

  test "convert_to_ucs2, ok" do
    assert {:ok, new_list} = convert_to_ucs2([a: "привет", b: "пока"], :a)
    assert Keyword.equal?([a: <<4, 63, 4, 64, 4, 56, 4, 50, 4, 53, 4, 66>>, b: "пока"], new_list)
  end

  test "convert_to_ucs2, error" do
    assert {:error, _} = convert_to_ucs2([a: <<231, 232>>, b: "пока"], :a)
  end
end

