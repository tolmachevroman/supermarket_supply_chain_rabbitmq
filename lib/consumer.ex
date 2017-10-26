defmodule SupplyChain.Consumer do
  use GenServer
  use AMQP

  @exchange "supply_chain"

  ###############
  #External API

  def start_link(product) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, product, [])
  end

  def init(product) do
    {:ok, connection} = Connection.open("amqp://guest:guest@localhost")
    {:ok, channel} = Channel.open(connection)


    Exchange.direct(channel, @exchange, durable: true)

    {:ok, %{queue: queue_name}} = Queue.declare(channel, "", durable: true)
    Queue.bind(channel, queue_name, @exchange, routing_key: product)


    Basic.qos(channel, prefetch_count: 10)
    {:ok, _consumer_tag} = Basic.consume(channel, queue_name)
    {:ok, channel}
  end

end
