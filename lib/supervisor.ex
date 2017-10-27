defmodule SupermarketSupplyChainRabbitmq.Supervisor do
  use Supervisor

  @stock 10_000

  def start_link(products) do
    {:ok, _pid} = Supervisor.start_link(__MODULE__, products)
  end

  def init(products) do

    child_processes = Enum.reduce(
      products,
      [],
      fn product, list ->
         [worker(SupplyChain.Consumer, [product, @stock], id: product) | list]
       end
    )

    IO.inspect child_processes
    supervise(child_processes, strategy: :one_for_one)
  end
end
