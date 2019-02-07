use Mix.Config

config :elixir_rabbit,
  amqp_uris: ["amqp://localhost:5672"],
  exchange: [
    name: "my_exchange",
    type: :topic,
    durable: true
  ],
  queue: [
    name: "my_queue",
    auto_delete: true
  ],
  bind_options: [
    routing_key: "#"
  ],
  output_file: "output.txt"
