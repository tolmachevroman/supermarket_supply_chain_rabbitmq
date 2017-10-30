defmodule SupermarketSupplyChain.Consumer do
  use GenServer
  use AMQP
  alias SupermarketSupplyChain.Product
  alias SupermarketSupplyChain.ProductsServer

  @exchange "supply_chain"

  def start_link(products) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, products)
  end

  def init(products) do
    {:ok, connection} = Connection.open("amqp://guest:guest@localhost")
    {:ok, channel} = Channel.open(connection)

    Exchange.direct(channel, @exchange, durable: true)
    
    # Declare queues, one per product, bound to Exchange by product's id
    for product <- products do
      queue_name = "amqp.queue." <> product.name
      Queue.declare(channel, queue_name, exclusive: true)
      Queue.bind(channel, queue_name, @exchange, routing_key: product.id)
      Basic.consume(channel, queue_name)
    end

    Basic.qos(channel, prefetch_count: 10)
    {:ok, channel}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, channel) do
    {:noreply, channel}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, channel) do
    {:stop, :normal, channel}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, channel) do
    {:noreply, channel}
  end

  # Sent by the broker when a message is delivered
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: _redelivered}}, channel) do

    # Payload comes in form of String, and contains product id and requested quantity
    # For example, "1.1500"
    # We then process the order, depending on actual quantity the product has
    [product_id, quantity] = String.split(payload, ".")
    spawn fn ->
      process_order(channel, tag, product_id, quantity)
    end

    {:noreply, channel}
  end

  defp process_order(channel, tag, product_id, quantity) do
    product = ProductsServer.find_product(product_id)

    new_quantity = String.to_integer(product.quantity) - String.to_integer(quantity)

    # Reject or acknowledge the message depending on quantity requested, and update state of the product
    cond do
       new_quantity < 0 ->
          IO.puts "Cannot buy #{product.name}, not enough quantity"
          Basic.reject(channel, tag, requeue: false)
          ProductsServer.update_quantity(product.id, product.quantity)
      new_quantity < String.to_integer(Product.threshold) ->
          IO.puts "Buying more #{product.name}..."
          Basic.ack(channel, tag)
          ProductsServer.update_quantity(product.id, Product.default_quantity)
      true ->
          IO.puts "Ok, thanks for buying"
          Basic.ack(channel, tag)
          ProductsServer.update_quantity(product.id, Integer.to_string(new_quantity))
    end

  end

end
