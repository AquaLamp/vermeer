defmodule Vermeer.MixProject do
  use Mix.Project

  def project do
    [
      app: :vermeer,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :noise]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:noise, "~> 0.0.2"},
      {:flow, "~> 1.0.0"}
    ]
  end
end
