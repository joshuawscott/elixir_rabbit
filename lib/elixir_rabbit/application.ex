defmodule ElixirRabbit.Application do
  @moduledoc "Application startup module"

  use Application

  alias ElixirRabbit.Reader

  def start(_, _) do
    {connection, channel, queue_name} =
      with {:ok, queue_options} <- fetch_env(:queue),
           {:ok, exchange_options} <- fetch_env(:exchange),
           {:ok, amqp_uris} <- fetch_env(:amqp_uris),
           {:ok, {queue_name, _queue_options}} <-
             pop_fetch(queue_options, :name, "Missing Queue Name"),
           {:ok, {exchange_name, exchange_options}} <-
             pop_fetch(exchange_options, :name, "Missing Exchange Name"),
           {exchange_type, exchange_options} when exchange_type != nil <-
             Keyword.pop(exchange_options, :type, :direct),
           {:ok, connection} <- AMQP.Connection.open(Enum.random(amqp_uris)),
           {:ok, channel} <- AMQP.Channel.open(connection),
           :ok <- AMQP.Exchange.declare(channel, exchange_name, exchange_type, exchange_options),
           {:ok, _} <- AMQP.Queue.declare(channel, queue_name) do
        bind_options = Application.get_env(:elixir_rabbit, :bind_options)
        AMQP.Queue.bind(channel, queue_name, exchange_name, bind_options)
        {connection, channel, queue_name}
      else
        {:error, msg} ->
          raise(inspect(msg))
      end

    {:ok, filename} = fetch_env(:output_file)

    children = [
      {Reader, {channel, queue_name, filename}}
    ]

    options = [strategy: :one_for_one]
    {:ok, supervisor} = Supervisor.start_link(children, options)
    {:ok, supervisor, connection}
  end

  def stop(connection) do
    AMQP.Connection.close(connection)
  end

  defp fetch_env(key) do
    case Application.fetch_env(:elixir_rabbit, key) do
      :error ->
        {:error, {:key_not_found, key}}

      {:ok, value} ->
        {:ok, value}
    end
  end

  # returns {:ok, {value, new_list}} or {:error, default}
  defp pop_fetch(keyword_list, key, default) do
    ref = make_ref()

    case Keyword.pop(keyword_list, key, ref) do
      {^ref, ^keyword_list} -> {:error, default}
      val -> {:ok, val}
    end
  end
end
