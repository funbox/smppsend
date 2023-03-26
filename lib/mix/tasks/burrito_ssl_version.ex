defmodule Mix.Tasks.Burrito.Ssl.Version do
  @moduledoc "Export OpenSSL version for Burrito builds: `mix help burrito_otp_version`"
  @shortdoc "Print OpenSSL version for burrito builds"
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    IO.puts(Mix.Project.config()[:burrito_ssl_version])
  end
end
