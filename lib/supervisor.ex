defmodule SupermarketSupplyChain.Supervisor do
  use Supervisor

  def start_link(products) do
    {:ok, _pid} = Supervisor.start_link(__MODULE__, products)
  end

  def init(products) do

    child_processes = Enum.map(
      products,
      fn product ->
         worker(SupermarketSupplyChain.Consumer, [product], id: product.id)
       end
    )

    # IO.inspect child_processes
    supervise(child_processes, strategy: :one_for_one)
  end
end
