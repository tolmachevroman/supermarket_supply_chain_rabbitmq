defmodule SupplyChain.Producer do
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

  # Emulate constant flow of messages
  def loop_buying do
    GenServer.cast(__MODULE__, {:buy, :rand.uniform(1000)})
    :timer.sleep(2)
    loop_buying()
  end

  def handle_cast({:buy, quantity}, channel) do
    Basic.publish(channel, @exchange, Integer.to_string(:rand.uniform(3)),
      Integer.to_string(quantity))
    {:noreply, channel}
  end
end
