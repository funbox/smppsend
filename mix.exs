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
      {:smppex, git: "https://github.com/savonarola/smppex.git", only: :dev},
      {:dye, "~> 0.4.0", only: :dev}
    ]
  end

  def escript do
    [main_module: Smppsend]
  end
end
