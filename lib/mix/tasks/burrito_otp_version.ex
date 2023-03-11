defmodule Mix.Tasks.Burrito.Otp.Version do
  @moduledoc "Export OTP version for Burrito builds: `mix help burrito_otp_version`"
  @shortdoc "Print OTP version for burrito builds"
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    IO.puts(Mix.Project.config()[:burrito_otp_version])
  end
end
