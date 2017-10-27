defmodule SupermarketSupplyChainRabbitmqTest do
  use ExUnit.Case
  use AMQP

  test "establish connection and send a message" do
    {:ok, connection} = Connection.open
    {:ok, channel} = Channel.open(connection)

    Basic.publish(channel, "supply_chain", "1", "10") # Milk has id "1"
    Connection.close(connection)

    assert true
  end
end
