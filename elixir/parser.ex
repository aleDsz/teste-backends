defmodule Parser do
  @fields [
    value: :float,
    income: :float,
    installment: :integer,
    is_main: :boolean,
    age: :integer,
    timestamp: :datetime
  ]

  def decode!(file_data) do
    file_data
    |> String.split("\n")
    |> Enum.map(&String.split(&1, ","))
    |> generate_structs()
    |> case do
      {:ok, structs} ->
        structs
        |> List.flatten()

      {:error, reason} ->
        raise reason
    end
  end

  defp generate_structs(lines) when is_list(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, structs} ->
      case line do
        [_event_id, schema, action | _tail] ->
          module =
            "Elixir"
            |> Module.concat(
              "#{schema |> String.capitalize()}" <>
              "#{action |> String.capitalize()}"
            )
          map = generate_struct(line, module)
          {:cont, {:ok, structs ++ [map]}}

        _ ->
          {:cont, {:error, "Unexpected format"}}
      end
    end)
  end

  defp generate_struct(line, module) do
    map =
      line
      |> generate_map(module.get_header())
      |> change_values()

    [
      module
      |> struct(map)
    ]
  end

  defp generate_map(list_data, header) do
    [
      header,
      list_data
    ]
    |> List.zip()
    |> Enum.into(%{})
  end

  defp change_values(map) do
    map
    |> Enum.map(fn {key, value} ->
      skey = key |> to_string()


      @fields
      |> Keyword.keys()
      |> Enum.map(&to_string/1)
      |> Enum.find(& skey =~ &1)
      |> case do
        nil ->
          {key, value}

        akey ->
          akey = String.to_atom(akey)
          {key, value |> convert(@fields[akey])}
      end
    end)
    |> Enum.into(%{})
  end

  defp convert(value, :float), do: String.to_float(value)
  defp convert(value, :integer), do: String.to_integer(value)
  defp convert(value, :boolean), do: value === "true"
  defp convert(value, :datetime), do: DateTime.from_iso8601(value) |> elem(1)
end
