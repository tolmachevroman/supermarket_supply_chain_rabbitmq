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


