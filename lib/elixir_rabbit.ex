defmodule ElixirRabbit do
  @moduledoc false

  def connect_with_retry(uri, retries) do
    do_connect_with_retry(uri, retries, 1)
  end

  def do_connect_with_retry(_, max_retries, retry_number) when retry_number > max_retries do
    {:error, {:max_retries_reached, max_retries}}
  end

  def do_connect_with_retry(uri, max_retries, retry_number) do
    case AMQP.Connection.open(uri) do
      {:ok, connection} ->
        {:ok, connection}
      {:error, _} ->
        :timer.sleep(retry_number * retry_number * 1000)
        do_connect_with_retry(uri, max_retries, retry_number + 1)
    end
  end
end
