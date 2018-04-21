defmodule CallSync.Mixfile do
  use Mix.Project

  def project do
    [
      app: :call_sync,
      version: "0.0.2",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CallSync, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_), do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0-rc"},
      {:phoenix_pubsub, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:quantum, ">= 2.2.1"},
      {:flow, "~> 0.11"},
      {:short_maps, "~> 0.1.2"},
      {:poison, "~> 3.1"},
      {:timex, "~> 3.1"},
      {:distillery, "~> 1.0.0"},
      {:httpoison, "~> 1.0"},
      {:httpotion, "~> 3.0.3"},
      {:mongodb, "~> 0.4.3"},
      {:poolboy, "~> 1.5.1"},
      {:nimble_csv, "~> 0.3"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.6"},
      {:honeydew, "~> 1.0.4"}
    ]
  end
end
