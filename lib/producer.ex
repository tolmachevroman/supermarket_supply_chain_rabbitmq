defmodule SupermarketSupplyChain.Producer do
  use GenServer
  use AMQP

  @exchange "supply_chain"

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, connection} = Connection.open
    {:ok, channel} = Channel.open(connection)
    {:ok, channel}
  end

  # Emulate one-time buy message
  def buy(quantity) do
    GenServer.cast(__MODULE__, {:buy, quantity})
  end

  # Emulate constant flow of messages
  def loop_buying do
    buy(:rand.uniform(1000))
    # Adding even 1 millisecond of timeout between messages dramatically diminishes load
    :timer.sleep(1)
    loop_buying()
  end

  # Publishes message to one of 3 available queues (products), with given quantity payload
  def handle_cast({:buy, quantity}, channel) do
    Basic.publish(channel, @exchange, Integer.to_string(:rand.uniform(3)),
      Integer.to_string(quantity))
    {:noreply, channel}
  end
end
