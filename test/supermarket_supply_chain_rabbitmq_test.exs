defmodule SupermarketSupplyChainRabbitmqTest do
  use ExUnit.Case
  use AMQP

  test "establish connection and send messages" do
    {:ok, connection} = Connection.open
    {:ok, channel} = Channel.open(connection)

    users_buying = 1000

    for n <- 1..users_buying do
        Task.async(
          fn ->
            # :timer.sleep(5)
            Basic.publish(channel, "supply_chain", Integer.to_string(:rand.uniform(3)),
              Integer.to_string(n))
          end
        )
    end

    # Send parallel requests to buy one of the three products, up to ten thousand units one time
    # pmap(1..users_buying, fn n ->
    #   Basic.publish(channel, "supply_chain", Integer.to_string(:rand.uniform(3)), Integer.to_string(:rand.uniform(10000)))
    #   # if n == users_buying do
    #   #   :timer.sleep(500)
    #   #   Connection.close(connection)
    #   # end
    # end)

    assert true
  end

  defp pmap(collection, func) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(&Task.await/1)
  end
end
