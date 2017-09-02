defmodule SMPPSend.VersionTest do
  use ExUnit.Case

  test "version" do
    assert {:ok, _} = Version.parse(SMPPSend.Version.version)
  end
end
