defmodule Smppsend.Mixfile do
  use Mix.Project

  def project do
    [
      app: :smppsend,
      version: "0.1.16",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      escript: escript(),
      test_coverage: [tool: Coverex.Task]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :xmerl]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:smppex, "~> 2.0"},
      {:dye, "~> 0.4.0"},
      {:coverex, "~> 1.4.1", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:codepagex, "~> 0.1.6"}
    ]
  end

  def escript do
    [main_module: SMPPSend]
  end
end
