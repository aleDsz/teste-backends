defmodule Main do
  require Logger
  @folder "../test/input"

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

  defp load_files() do
    File.ls!(@folder)
    |> Enum.map(fn file ->
      File.read!("#{@folder}/#{file}")
    end)
  end
end

Main.run()
