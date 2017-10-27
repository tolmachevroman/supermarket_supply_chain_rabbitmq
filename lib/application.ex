defmodule SupermarketSupplyChainRabbitmq.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias SupplyChain.Product

  @products [
    %Product{id: "1", name: "Milk"},
    %Product{id: "2", name: "Beer"},
    %Product{id: "3", name: "Juice"}
  ]

  def start(_type, _args) do
    {:ok, _pid} = SupermarketSupplyChainRabbitmq.Supervisor.start_link(@products)
  end
end
