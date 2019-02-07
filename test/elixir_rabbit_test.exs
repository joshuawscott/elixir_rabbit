defmodule ElixirRabbitTest do
  use ExUnit.Case, async: false

  alias ElixirRabbit.Reader

  setup do
    amqp_uri = Enum.random(Application.get_env(:elixir_rabbit, :amqp_uris))
    {:ok, connection} = AMQP.Connection.open(amqp_uri)
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, exchange} = Application.fetch_env(:elixir_rabbit, :exchange)
    filename = "output_#{:rand.uniform(10_000)}"

    on_exit(fn ->
      :ok
      #File.rm(filename)
    end)

    {:ok,
     %{
       channel: channel,
       exchange_name: exchange[:name],
       filename: filename
     }}
  end

  def wait_for_queue(channel, queue, ms \\ 1000) do
    tries = ms / 10
    Enum.find(1..trunc(tries), fn _ ->
      :timer.sleep(10)
      AMQP.Queue.empty?(channel, queue)
    end)
  end

  def wait_for_file_write(filename, ms \\ 1000) do
    tries = ms / 10
    Enum.find(1..trunc(tries), fn _ ->
      first_size = byte_size(File.read!(filename))
      :timer.sleep(10)
      second_size = byte_size(File.read!(filename))
      first_size == second_size
    end)
  end

  # End to end test using the config
  test "write a consumed message to a file, and ensure it was ack'd", t do
    {:ok, output_file} = Application.fetch_env(:elixir_rabbit, :output_file)
    {:ok, queue} = Application.fetch_env(:elixir_rabbit, :queue)
    routing_key = ""

    message = "Hello, Human #{:rand.uniform(10_000)}"
    AMQP.Basic.publish(t.channel, t.exchange_name, routing_key, message)

    wait_for_queue(t.channel, queue[:name])
    wait_for_file_write(output_file)

    {:ok, content} = File.read(output_file)

    expected_content = message <> "\n"

    assert expected_content == content

    message2 = "Hello, Human #{:rand.uniform(10_000)}"
    AMQP.Basic.publish(t.channel, t.exchange_name, routing_key, message2)

    wait_for_queue(t.channel, queue[:name])
    wait_for_file_write(output_file)

    {:ok, content} = File.read(output_file)

    expected_content = message <> "\n" <> message2 <> "\n"
    assert expected_content == content
  end

  test "write many consumed messages to a file in order", t do
    routing_key = ""
    queue_name = "my_other_queue"
    exchange_name = "my_other_exchange"
    AMQP.Exchange.declare(t.channel, exchange_name, :topic, durable: false)
    AMQP.Queue.declare(t.channel, queue_name)
    AMQP.Queue.bind(t.channel, queue_name, exchange_name)
    {:ok, reader} = Reader.start_link({t.channel, queue_name, t.filename})

    messages =
      for n <- 1..1000 do
        "Hello, Human #{n}"
      end

    messages
    |> Enum.each(fn message ->
      AMQP.Basic.publish(t.channel, exchange_name, routing_key, message)
    end)

    wait_for_queue(t.channel, queue_name)
    wait_for_file_write(t.filename)

    {:ok, content} = File.read(t.filename)

    expected_content = Enum.join(messages, "\n") <> "\n"

    assert expected_content == content
    GenServer.stop(reader)
  end
end
