defmodule SupplyChain.Product do

  @default_quantity 10_000

  defstruct [:id, :name, quantity: @default_quantity]
end
