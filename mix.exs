defmodule Filters.MixProject do
  use Mix.Project

  def project do
    [
      app: :filters,
      version: "0.1.0",
      elixir: "~> 1.13",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct, "~> 0.2.1"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Simple filter capabilities for your data"
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib mix.exs README.md),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/riccardomanfrin/filters"}
    ]
  end
end
