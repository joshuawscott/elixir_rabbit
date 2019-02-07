defmodule ElixirRabbit.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_rabbit,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {ElixirRabbit.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.1"},
      {:credo, "~> 1.0", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev}
    ]
  end
end
