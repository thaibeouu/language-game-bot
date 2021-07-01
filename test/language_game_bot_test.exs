defmodule LanguageGameBotTest do
  use ExUnit.Case
  doctest LanguageGameBot

  test "greets the world" do
    assert LanguageGameBot.hello() == :world
  end
end
