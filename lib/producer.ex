defmodule SupermarketSupplyChain.Producer do
  use GenServer
  use AMQP

  @exchange "supply_chain"

  def start_link do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, connection} = Connection.open
    {:ok, channel} = Channel.open(connection)
    {:ok, channel}
  end

  # Emulate one-time buy message
  def buy(pid, quantity) do
    GenServer.cast(pid, {:buy, quantity})
  end

  # Emulate constant flow of messages
  def loop_buying(pid) do
    buy(pid, :rand.uniform(3000))
    # Add random millisecond delay between messages
    :timer.sleep(:rand.uniform(1))
    loop_buying(pid)
  end

  # Publishes message to one of available queues (products), with given quantity payload
  def handle_cast({:buy, quantity}, channel) do
    # Routing keys are products' ids
    queue_routing_key = Integer.to_string(:rand.uniform(1000))
    payload = Integer.to_string(:rand.uniform(1000)) <> "." <> Integer.to_string(quantity)
    Basic.publish(channel, @exchange, queue_routing_key, payload)
    {:noreply, channel}
  end
end
