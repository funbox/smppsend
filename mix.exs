defmodule Smppsend.Mixfile do
  use Mix.Project

  @burrito_otp_version "25.2.3"
  @burrito_ssl_version "1.1.1s"

  def project do
    [
      app: :smppsend,
      version: "0.1.23",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      escript: escript(),
      test_coverage: [tool: Coverex.Task],
      releases: releases(),
      burrito_otp_version: @burrito_otp_version,
      burrito_ssl_version: @burrito_ssl_version
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :xmerl],
      mod: {SMPPSend, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def releases do
    [
      smppsend: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            # linux_aarch64: [
            #   os: :linux,
            #   cpu: :aarch64,
            #   custom_erts: "burrito/otp/versions/otp-#{@burrito_otp_version}-linux-aarch64.tar.gz"
            # ],
            linux_x86_64: [
              os: :linux,
              cpu: :x86_64,
              custom_erts: "burrito/otp/versions/otp-#{@burrito_otp_version}-linux-x86_64.tar.gz"
            ],
            # darwin_aarch64: [
            #   os: :darwin,
            #   cpu: :aarch64,
            #   custom_erts: "burrito/otp/versions/otp-#{@burrito_otp_version}-darwin-aarch64.tar.gz"
            # ],
            # darwin_x86_64: [
            #   os: :darwin,
            #   cpu: :x86_64,
            #   custom_erts: "burrito/otp/versions/otp-#{@burrito_otp_version}-linux-x86_64.tar.gz"
            # ],
          ]
        ]
      ]
    ]
  end

  defp deps do
    [
      {:smppex, "~> 2.0"},
      {:dye, "~> 0.4.0"},
      {:codepagex, "~> 0.1.6"},
      {:burrito, github: "burrito-elixir/burrito"},

      {:coverex, "~> 1.4.1", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  def escript do
    [main_module: SMPPSend]
  end
end
