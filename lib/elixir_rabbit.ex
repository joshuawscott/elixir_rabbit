defmodule ElixirRabbit do
  defmodule Writer do
    use GenServer

    defmodule State do
      defstruct [:channel, :exchange, :routing_key, :options]
    end

    def start_link([exchange]) do
      start_link([exchange, "", []])
    end

    def start_link([exchange, routing_key]) do
      start_link([exchange, routing_key, []])
    end

    def start_link([_exchange, _routing_key, _options] = args) do
      GenServer.start_link(__MODULE__, args)
    end

    def publish(pid, payload) do
      GenServer.cast(pid, {:publish, payload})
    end

    def init([exchange, routing_key, options]) do
      {:ok, connection} = AMQP.Connection.open()
      {:ok, channel} = AMQP.Channel.open(connection)

      {
        :ok,
        %State{
          channel: channel,
          exchange: exchange,
          routing_key: routing_key,
          options: options
        }
      }
    end

    def handle_cast({:publish, payload}, state) do
      AMQP.Basic.publish(state.channel, state.exchange, state.routing_key, payload, state.options)
      {:noreply, state}
    end
  end
end
