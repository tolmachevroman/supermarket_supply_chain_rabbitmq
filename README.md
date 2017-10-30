# Supermarket sample supply - consumption model with RabbitMQ and Elixir

[RabbitMQ](https://www.rabbitmq.com/) is a popular open source message broker used by companies like Trivago or Instagram. Written in Erlang, it's quite interesting tool to play using Elixir, to see how it works and how changing parameters affects load performance. Let's create a PubSub model with 1000 queues and a publisher, which will be pushing messages constantly.

For this, we'll simulate consumption model for some abstract products in an abstract supermarket. Supermarket has some products with default quantity, so a) when somebody tries to buy more than there's in the stock, request fails b) if new quantity is less than the threshold, we sell and refill the stock and c) otherwise just sell happily

## RabbitMQ scheme

Messages flow scheme representing this will be the following:

![](https://user-images.githubusercontent.com/560815/32159053-84cfc8a8-bd2a-11e7-96e0-dbd974f7ee86.png)

<b>P(roducer)</b> generates a message, <b>E(xchange)</b> processes it and sends to <b>Q(ueues)</b> bound by routing key, which will be product's id. So each product has it's dedicated queue. This may not be optimal for a real life task, but for our goal it's fine. After that, message will go to the <b>C(onsumer)</b> which acknowledges or rejects it depending on the payload. Finally, it will update requested product's quantity in the <b>S(tore)</b>.

## Elixir project

To construct this using Elixir, we'll use simple Elixir OTP application and [AMQP wrapper](https://github.com/pma/amqp). RabbitMQ broker will be running on the localhost, waiting for our messages from Elixir Producer module, dispatching them to Elixir Consumers, each consumer representing one Product.

[Product](lib/product.ex) module needs to have id, name and quantity, and a couple of default values as well. RabbitMQ operates with binary format, so struct also has to use binary format even for numbers.

```elixir
 @default_quantity "10000"
 @threshold "7000"

 defstruct [:id, :name, quantity: @default_quantity]
```

[Application](lib/application.ex) will start with predefined list of products.

```elixir
# [ %Product{id: "1", name: "Product1", quantity: "10000"}, ... ]
@products Enum.map(1..1000, fn n ->
     %Product{id: Integer.to_string(n), name: "Product" <> Integer.to_string(n)}
end)
```

We will supervise Consumer and [ProductsServer](lib/products_server.ex) workers, former receiving and processesing messages and notifying the latter.

```elixir
def start_link(products) do
  # Consumer receives messages from RabbitMQ and passes them to ProductsServer to update items
  children = [
    worker(Consumer, [products]),
    worker(ProductsServer, [products])
  ]

  {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
end
```

[Consumer](lib/consumer.ex) connects to the localhost with default params. We generate declare queues by names to evade creating random queues each time GenServer is started and bind them to a common Exchange entity.

```elixir
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
```

Besides of default callbacks for AMQP module, the most interesting part happens when the payload comes:

```elixir
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
```

Here we apply desired logic depending on quantity requested and actual quantity of the Product. Depending on it we acknowledge or reject the message and update the quantity.

```elixir
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
```

Finally, [Producer](lib/producer.ex) is a GenServer that connects to the same Exchange and publishes messages. To generate constant message flow, we'll loop message publishing:

```elixir
# Emulate one-time buy message
def buy(quantity) do
  GenServer.cast(__MODULE__, {:buy, quantity})
end

# Emulate constant flow of messages
def loop_buying() do
  # Buy up to 3000 items of a product
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
```

Running the dummy test

```elixir
@tag timeout: :infinity
test "run message producer" do
  SupermarketSupplyChain.Producer.start_link
  SupermarketSupplyChain.Producer.loop_buying()
  assert true
end
```

we can see in the dashboard that RabbitMQ processes messages successfully, maintaining queues healthy even with that constant flood of events:

![](https://user-images.githubusercontent.com/560815/32159054-84f5cfee-bd2a-11e7-984f-53869eb4be30.png)

![](https://user-images.githubusercontent.com/560815/32159055-851b519c-bd2a-11e7-9fa5-6c647e1bdb2e.png)
