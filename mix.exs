defmodule Hookshot.MixProject do
  use Mix.Project

  def project do
    [
      app: :hookshot,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ex_rated]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:ecto_sql, "~> 3.6"},
      {:broadway, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:ex_rated, "~> 2.0"}
    ]
  end
end
