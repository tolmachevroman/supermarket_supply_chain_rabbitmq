defmodule SupplyChain.Consumer do
  use GenServer
  use AMQP

  @exchange "supply_chain"

  ###############
  #External API

  def start_link(product, stock) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, {product, stock})
  end

  def init({product, stock}) do
    {:ok, connection} = Connection.open("amqp://guest:guest@localhost")
    {:ok, channel} = Channel.open(connection)

    Exchange.direct(channel, @exchange, durable: true)

    {:ok, %{queue: queue_name}} = Queue.declare(channel, "", exclusive: true)
    Queue.bind(channel, queue_name, @exchange, routing_key: product)


    Basic.qos(channel, prefetch_count: 10)
    {:ok, _consumer_tag} = Basic.consume(channel, queue_name)
    {:ok, {channel, stock}}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, {channel, stock}) do
    {:noreply, {channel, stock}}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, {channel, stock}) do
    {:stop, :normal, {channel, stock}}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, {channel, stock}) do
    {:noreply, {channel, stock}}
  end

  # Sent by the broker when a message is delivered
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, {channel, stock}) do
    spawn fn -> consume({channel, stock}, tag, redelivered, payload) end
    {:noreply, {channel, stock}}
  end

  def consume({channel, stock}, tag, redelivered, payload) do
    number = String.to_integer(payload)
    IO.puts "Received #{number}"

    IO.puts "Stock is #{stock}"

  end
end
