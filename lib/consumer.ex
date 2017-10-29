defmodule SupermarketSupplyChain.Consumer do
  use GenServer
  use AMQP
  alias SupermarketSupplyChain.Product

  @exchange "supply_chain"

  def start_link(product) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, product)
  end

  def init(product) do
    {:ok, connection} = Connection.open("amqp://guest:guest@localhost")
    {:ok, channel} = Channel.open(connection)

    IO.puts "init #{product.name}"

    queue_name = "amqp.queue." <> product.name
    Exchange.direct(channel, @exchange, durable: true)
    Queue.declare(channel, queue_name, exclusive: true)
    Queue.bind(channel, queue_name, @exchange, routing_key: product.id)

    Basic.qos(channel, prefetch_count: 10)
    Basic.consume(channel, queue_name)
    {:ok, {channel, product}}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, {channel, product}) do
    {:noreply, {channel, product}}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, {channel, product}) do
    {:stop, :normal, {channel, product}}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, {channel, product}) do
    {:noreply, {channel, product}}
  end

  # Sent by the broker when a message is delivered
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: _redelivered}},
      {channel, product}) do
    IO.puts "Trying to buy #{payload} of #{product.name}, with stock quantity of #{product.quantity}"

    # Emulate supply if we consumed more than the threshold of the product
    quantity_bought = String.to_integer(payload)
    quantity = String.to_integer(product.quantity)
    new_quantity = quantity - quantity_bought

    cond do
       new_quantity < 0 ->
        spawn fn ->
          IO.puts "Cannot buy #{product.name}, not enough quantity"
          Basic.reject(channel, tag, requeue: false)
        end
         {:noreply, {channel, product}}
      new_quantity < String.to_integer(Product.threshold) ->
        spawn fn ->
          IO.puts "Buying more #{product.name}..."
          Basic.ack(channel, tag)
        end
        {:noreply, {channel, %Product{product | quantity: Product.default_quantity}}}
      true ->
        spawn fn ->
          IO.puts "Ok, thanks for buying"
          Basic.ack(channel, tag)
        end
        {:noreply, {channel, %Product{product | quantity: Integer.to_string(new_quantity)}}}
    end

  end

end
