defmodule SupermarketSupplyChain.ProductsServer do
  use Agent
  alias SupermarketSupplyChain.Product

  # %{ "1" => %Product(id: "1", name: "Product1", quantity: "10000"), ... }
  def start_link(products) do
    {:ok, _pid} = Agent.start_link(fn -> products |> Map.new(fn product -> {product.id, product} end) end, name: __MODULE__)
  end

  def find_product(product_id) do
    Agent.get(__MODULE__, fn map -> map[product_id] end)
  end

  def update_quantity(product_id, new_quantity) do
    product = %Product{find_product(product_id) | quantity: new_quantity}
    Agent.update(__MODULE__, fn map -> %{map | product_id => product} end)
  end

end
