defmodule Scrabble do
  @headers [
    :end_time,
    :game_uuid,
    :round,
    :nickname,
    :points,
    :score,
    :scrabble_total,
    :words,
    :discards,
    :letters,
    :exhaustive_draw_count,
    :exhaustive,
    :ronned
  ]

  def game_to_csv_file(game_uuid, destination) do
    file = File.open!(destination, [:write, :utf8])

    game_uuid
    |> game_to_rows()
    |> CSV.encode(headers: @headers)
    |> Enum.each(&IO.write(file, &1))
  end

  def game_to_rows(game_uuid) do
    {head, events} =
      case Scrabble.Client.fetch_game(game_uuid) do
        {:ok, result} -> result
        {:error, error_code} -> raise "could not fetch the log: #{error_code}"
      end

    end_time = head.end_time |> DateTime.from_unix!() |> Calendar.strftime("%c")
    state = Scrabble.State.from_log(head, events)
    state_with_scores = Scrabble.Scoring.score_game(state)

    state_with_scores
    |> Enum.flat_map(&format_round/1)
    |> Enum.map(&Map.put(&1, :game_uuid, game_uuid))
    |> Enum.map(&Map.put(&1, :end_time, end_time))
  end

  defp format_round(round) do
    for player <- round do
      discards = format_discards(player.discards, " ")

      letters =
        player.letters
        |> Enum.map(fn {letter, _value} -> letter end)
        |> format_discards()

      words =
        player.words
        |> Enum.map(fn {letter, value} -> "#{letter}(#{value})" end)
        |> Enum.join(" ")

      player
      |> Map.drop([:groups, :seat])
      |> Map.put(:discards, discards)
      |> Map.put(:letters, letters)
      |> Map.put(:words, words)
    end
  end

  defp format_discards(enum, joiner \\ "") do
    enum
    |> Enum.chunk_every(6)
    |> Enum.map(&Enum.join(&1, joiner))
    |> Enum.join("\n")
  end
end
