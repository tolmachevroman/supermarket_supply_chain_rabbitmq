defmodule SupermarketSupplyChainTest do
  use ExUnit.Case

  @tag timeout: :infinity
  test "run multiple producers" do

    for n <- 1.. 1000 do
      {:ok, pid} = SupermarketSupplyChain.Producer.start_link
      SupermarketSupplyChain.Producer.loop_buying(pid)
    end

    assert true
  end

end
