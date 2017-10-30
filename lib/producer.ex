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
  def loop_buying() do
    buy(:rand.uniform(3000))
    loop_buying()
  end

  # Publishes message to one of available queues (products), with given quantity payload
  def handle_cast({:buy, quantity}, channel) do
    # Randomly publish message to some queue by it's routing id, which is product's id
    # Payload takes form of "product's id . quantity"
    queue_routing_key = Integer.to_string(:rand.uniform(1000))
    payload = Integer.to_string(:rand.uniform(1000)) <> "." <> Integer.to_string(quantity)
    Basic.publish(channel, @exchange, queue_routing_key, payload)
    {:noreply, channel}
  end
end
