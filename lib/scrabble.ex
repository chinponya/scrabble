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
    :letters,
    :discards,
    :dora_indicators,
    :ronned,
    :exhaustive_draw_count,
    :exhaustive
  ]

  def contest_word_stats_to_csv(contest_id, destination) do
    file = File.open!(destination, [:write, :utf8])
    headers = [:word, :value]

    contest_id
    |> contest_to_rows()
    |> Enum.flat_map(fn row ->
      words = String.split(row[:words], " ")

      for word <- words, word != "" do
        [word, value] =
          word
          |> String.replace(")", "")
          |> String.split("(", parts: 2)

        %{word: word, value: value}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> CSV.encode(headers: headers)
    |> Enum.each(&IO.write(file, &1))
  end

  def summarize(rows) do
    Enum.reduce(rows, %{}, fn row, acc ->
      game_default = %{
        end_time: row.end_time,
        points: row.points,
        score: row.score,
        bonus: row.scrabble_total
      }

      default = %{
        row.game_uuid => game_default
      }

      Map.update(acc, row.nickname, default, fn result ->
        Map.update(result, row.game_uuid, game_default, fn game_result ->
          Map.update(game_result, :bonus, 0, fn bonus -> bonus + row.scrabble_total end)
        end)
      end)
    end)
  end

  def flatten_summary(summary) do
    summary
    |> Enum.sort_by(fn {nickname, _} -> String.downcase(nickname) end)
    |> Enum.map(fn {nickname, value} ->
      value
      |> Enum.sort_by(fn {_game_id, result} -> result.end_time end)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {{_game_id, result}, index} ->
        [{"#{index} game", result.score}, {"#{index} bonus", result.bonus}]
      end)
      |> Map.new()
      |> Map.put("player", nickname)
    end)
  end

  def contest_summary_to_csv_file(contest_id, destination) do
    header =
      Enum.flat_map(1..10, fn index ->
        ["#{index} game", "#{index} bonus"]
      end)

    headers = ["player" | header]

    file = File.open!(destination, [:write, :utf8])

    contest_id
    |> contest_to_rows()
    |> summarize()
    |> flatten_summary()
    |> CSV.encode(headers: headers)
    |> Enum.each(&IO.write(file, &1))
  end

  def contest_to_csv_file(contest_id, destination) do
    file = File.open!(destination, [:write, :utf8])

    contest_id
    |> contest_to_rows()
    |> CSV.encode(headers: @headers)
    |> Enum.each(&IO.write(file, &1))
  end

  def contest_to_rows(contest_id) do
    majsoul_contest_id =
      case Scrabble.Client.fetch_contest_id_by_share_code(contest_id) do
        {:ok, result} -> result
        {:error, error_code} -> raise "could not fetch contest: #{error_code}"
      end

    majsoul_contest_id
    |> Scrabble.Client.fetch_contest_game_ids()
    |> Enum.flat_map(&game_to_rows/1)
  end

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
      dora_indicators = format_discards(player.dora_indicators, " ")

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
      |> Map.put(:dora_indicators, dora_indicators)
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
