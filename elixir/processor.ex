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

  defp process({file, messages}) when is_list(messages) do
    case Validator.check(messages) do
      {:ok, response} ->
        {:ok, {file, response}}

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Tried to parse message but received #{inspect reason}")
        {:error, reason}
    end
  end
end
