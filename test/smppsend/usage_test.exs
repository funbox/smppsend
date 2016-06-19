defmodule SMPPSend.UsageTest do
  use ExUnit.Case

  test "help" do
    assert is_binary(SMPPSend.Usage.help)
  end
end
