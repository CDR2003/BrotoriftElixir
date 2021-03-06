defmodule Brotorift.MixProject do
  use Mix.Project

  def project do
    [
      app: :brotorift,
      version: "0.4.4",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      description: description(),
      name: "Brotorift",
      source_url: "https://github.com/CDR2003/BrotoriftElixir"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ranch]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:ranch, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description() do
    "Server Brotorift runtime for Elixir."
  end

  defp package() do
    [
      name: "brotorift",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Peter Ren"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/CDR2003/BrotoriftElixir"}
    ]
  end
end
