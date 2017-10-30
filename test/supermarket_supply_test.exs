defmodule SupermarketSupplyChainTest do
  use ExUnit.Case

  @tag timeout: :infinity
  test "run message producer" do
    SupermarketSupplyChain.Producer.start_link
    SupermarketSupplyChain.Producer.loop_buying()
    assert true
  end

end
