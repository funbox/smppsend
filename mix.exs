defmodule Smppsend.Mixfile do
  use Mix.Project

  def project do
    [
      app: :smppsend,
      version: "0.1.8",
      elixir: "~> 1.1",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      escript: escript(),
      test_coverage: [tool: Coverex.Task]
    ]
  end

  def application do
    [applications: [:logger, :smppex]]
  end

  defp deps do
    [
      {:smppex, "~> 0.3.0"},
      {:dye, "~> 0.4.0"},
      {:coverex, "~> 1.4.1", only: :test},
      {:doppler, "~> 0.1.0", only: :test}
    ]
  end

  def escript do
    [main_module: SMPPSend]
  end
end
