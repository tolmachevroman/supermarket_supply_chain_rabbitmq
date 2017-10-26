defmodule SupplyChain.Consumer do
  use GenServer
  use AMQP

  @exchange "supply_chain"

  ###############
  #External API

  def start_link(product) do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init(product) do
    {:ok, connection} = Connection.open("amqp://guest:guest@localhost")
    {:ok, channel} = Channel.open


    Exchange.direct(channel, @exchange, durable: true)

    {:ok, %{queue: queue_name}} = Queue.declare(channel, "", durable: true)
    Queue.bind(channel, queue_name, @exchange, routing_key: product)


    Basic.qos(channel, prefetch_count: 10)
    {:ok, _consumer_tag} = Basic.consume(channel, queue_name)
    {:ok, channel}
  end

end
