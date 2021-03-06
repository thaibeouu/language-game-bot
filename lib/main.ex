defmodule App do
  use Application
  use Memoize

  require Logger

  defmemo read do
    Logger.info("Again?")

    {:ok, contents} = File.read("dict.txt")

    contents
    |> String.split("\r\n")
    |> Enum.to_list()
  end

  def check(term) do
    String.trim(term) in App.read()
  end

  @impl true
  def start(_type, _args) do
    :ets.new(:dicts, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    :ets.new(:states, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    :ets.new(:scores, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    BotSupervisor.start_link(name: BotSupervisor)
  end
end
