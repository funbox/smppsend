defmodule Smppsend.Mixfile do
  use Mix.Project

  def project do
    [
      app: :smppsend,
      version: "0.0.1",
      elixir: "~> 1.1",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      escript: escript
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:smppex, "~> 0.0.1"},
      {:dye, "~> 0.4.0"}
    ]
  end

  def escript do
    [main_module: SMPPSend]
  end
end
