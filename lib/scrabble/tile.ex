defmodule Scrabble.Tile do
  def successor_tile(tile) do
    {value, suit} =
      tile
      |> deaka()
      |> Integer.parse()

    max_value = if suit == "z", do: 7, else: 9

    new_value =
      case rem(value + 1, max_value) do
        0 -> max_value
        v -> v
      end

    "#{new_value}#{suit}"
  end

  def deaka(tile) do
    String.replace(tile, "0", "5")
  end

  def is_dora(tile, indicators) do
    tile = deaka(tile)

    Enum.any?(indicators, fn indicator ->
      tile == successor_tile(indicator)
    end)
  end
end
