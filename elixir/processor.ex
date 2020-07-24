defmodule Processor do
  require Logger

  def start(messages) do
    messages
    |> process()
    |> case do
      {:ok, messages} ->
        messages

      {:error, reason} ->
        raise reason
    end
  end

  defp process([messages | _tail] = all_messages) when is_list(all_messages) and is_list(messages) do
    all_messages
    |> Enum.reduce_while({:ok, []}, fn messages, {:ok, response} ->
      case process(messages) do
        {:ok, message} ->
          {:cont, {:ok, response ++ [message]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp process([item | _tail] = messages) when is_list(messages) and is_map(item) do
    case Validator.check(messages) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
