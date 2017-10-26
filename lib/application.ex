defmodule SupermarketSupplyChainRabbitmq.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @products ["milk", "beer", "juice"]

  def start(_type, _args) do
    {:ok, _pid} = SupermarketSupplyChainRabbitmq.Supervisor.start_link(@products)
  end
end
