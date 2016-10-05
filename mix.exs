defmodule FileServer.Mixfile do
  use Mix.Project

  def project do
    [app: :file_server,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [mod: {FileServer, []},
     applications: [:logger, :cowboy, :plug, :postgrex]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:cowboy, "~> 1.0.0"},
      {:plug, "~> 1.2"},
      {:cors_plug, "~> 1.1"},
      {:postgrex, "~> 0.12.0"},
      {:ecto, "~> 2.1.0-rc.1", override: true},
      {:joken, "~> 1.3"},
      {:poison, "~> 2.2", override: true},
      {:exactor, "~> 2.2"},
      {:arc, "~> 0.5.3"},
      {:arc_ecto, "~> 0.4.4"},
      {:zarex, "~> 0.3"},
      {:mimerl, "~> 1.1"},
      {:zipflow, github: "dgvncsz0f/zipflow"}
    ]
  end
end
