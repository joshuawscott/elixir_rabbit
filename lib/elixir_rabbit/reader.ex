defmodule ElixirRabbit.Reader do
  use GenServer
  require Logger

  def start_link([channel, queue, filename]) do
    GenServer.start_link(__MODULE__, [channel, queue, filename])
  end

  def init([channel, queue, filename]) do
    delete_file!(filename)
    {:ok, file} = File.open(filename, [:write])
    {:ok, %{file: file, channel: channel, queue: queue, consumer_tag: nil}, 0}
  end

  def handle_info(:timeout, state) do
    {:ok, consumer_tag} = AMQP.Basic.consume(state.channel, state.queue)
    {:noreply, %{state | consumer_tag: consumer_tag}}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: delivery_tag} = _metadata}, state) do
    IO.binwrite(state.file, [payload, "\n"])
    AMQP.Basic.ack(state.channel, delivery_tag)
    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    {:noreply, %{state | consumer_tag: consumer_tag}}
  end

  def handle_info(
        {:basic_cancel, %{consumer_tag: consumer_tag, no_wait: :no_wait}},
        %{consumer_tag: consumer_tag} = state
      ) do
    Logger.error("received a basic_cancel")
    {:noreply, state}
  end

  def handle_info(
        {:basic_cancel_ok, %{consumer_tag: consumer_tag}},
        %{consumer_tag: consumer_tag} = state
      ) do
    Logger.error("received a basic_cancel_ok")
    {:noreply, state}
  end

  def terminate(reason, state) do
    AMQP.Channel.close(state.channel)
  end

  defp delete_file!(path) do
    case File.rm(path) do
      :ok ->
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        raise File.Error, reason: reason, action: "remove file", path: IO.chardata_to_string(path)
    end
  end
end
