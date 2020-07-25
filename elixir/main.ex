defmodule Main do
  require Logger
  @folder "../test"
  @numbers [8]

  def run() do
    autoload()

    load_files()
    |> Enum.map(&Parser.decode!/1)
    |> Processor.start()
  end

  defp autoload() do
    Logger.info("[#{__MODULE__}] Autoloading modules...")

    ["./structs", "./parser.ex", "./validator.ex", "./processor.ex"]
    |> Enum.each(fn item ->
      Logger.info("[#{__MODULE__}] Autoloading: #{inspect item}")

      if File.dir?(item) do
        Logger.info("[#{__MODULE__}] Is a folder, so we need to load all files inside")

        item
        |> File.ls!()
        |> Enum.each(fn file ->
          file = "#{item}/#{file}"
          Logger.info("[#{__MODULE__}] Autoloading: #{inspect file}")
          Code.require_file(file)
        end)
      else
        Code.require_file(item)
      end
    end)
  end

  defp load_files(type \\ :input) do
    type = type |> to_string()
    folder = "#{@folder}/#{type}"

    @numbers
    |> Enum.map(fn i ->
      file_name =
        to_string(i)
        |> String.pad_leading(3, ["0"])

      file_name = "#{type}#{file_name}.txt"

      data = File.read!("#{folder}/#{file_name}")
      {file_name, data}
    end)
  end

  end
end

Main.run()
