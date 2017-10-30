defmodule SupermarketSupplyChain.Supervisor do
  use Supervisor
  alias SupermarketSupplyChain.Consumer
  alias SupermarketSupplyChain.ProductsServer

  def start_link(products) do

    # Consumer receives messages from RabbitMQ and passes them to ProductStore to update items
    children = [
      worker(Consumer, [products]),
      worker(ProductsServer, [products])
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end

end
