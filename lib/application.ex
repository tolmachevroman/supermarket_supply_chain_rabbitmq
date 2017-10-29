defmodule SupermarketSupplyChain.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias SupermarketSupplyChain.Product

  # @products [
  #   %Product{id: "1", name: "Milk"},
  #   %Product{id: "2", name: "Beer"},
  #   %Product{id: "3", name: "Juice"}
  # ]

  @products Enum.map(1..300, fn n ->
      %Product{id: Integer.to_string(n), name: "Product" <> Integer.to_string(n)}
    end)

  def start(_type, _args) do
    SupermarketSupplyChain.Supervisor.start_link(@products)
  end
end
