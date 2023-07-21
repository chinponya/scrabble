defmodule ScrabbleTest do
  use ExUnit.Case
  doctest Scrabble

  test "greets the world" do
    assert Scrabble.hello() == :world
  end
end
