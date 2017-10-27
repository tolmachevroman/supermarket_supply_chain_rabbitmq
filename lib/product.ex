defmodule SupplyChain.Product do

  @default_quantity "10000"
  @threshold "7000"

  defstruct [:id, :name, quantity: @default_quantity]

  def threshold, do: @threshold
end
