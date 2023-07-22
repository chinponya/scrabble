defmodule Scrabble.Scoring do
  @dictionary :code.priv_dir(:scrabble)
              |> Path.join("scrabble_dictionary.txt")
              |> File.read!()
              |> String.split("\n")
              |> Enum.reject(fn w -> String.length(w) < 3 end)
              |> MapSet.new()

  @wildcard {"?", 0.5}
  @tile_to_letter %{
    "1m" => {"i", 1},
    "1p" => {"i", 1},
    "1s" => {"i", 1},
    "4m" => {"a", 1},
    "4p" => {"a", 1},
    "4s" => {"a", 1},
    "7m" => {"t", 1},
    "7p" => {"t", 1},
    "7s" => {"t", 1},
    "8m" => {"b", 3},
    "8p" => {"b", 3},
    "8s" => {"b", 3},
    "1z" => {"e", 1},
    "2z" => {"s", 1},
    "3z" => {"w", 4},
    "4z" => {"n", 1},
    "5z" => @wildcard,
    "6z" => {"g", 2},
    "7z" => {"r", 1}
  }
  @stop_letter {"-", 0}
  @alphabet Enum.map(?a..?z, &to_string([&1]))
  @row_width 6
  @column_height 3

  def score_game(state) do
    for {round, round_num} <- Enum.with_index(state) do
      exhaustive_draw_count = count_exhaustive_draws_until(state, round_num)

      round
      |> Enum.map(&Map.put(&1, :round, round_num))
      |> Enum.map(&Map.put(&1, :exhaustive_draw_count, exhaustive_draw_count))
      |> score_round()
    end
  end

  defp score_round(round) do
    for player <- round do
      letters =
        player.discards
        |> discards_to_letters()
        |> Enum.zip(player.discards)
        |> Enum.map(fn {{letter, value}, tile} ->
          if Scrabble.Tile.is_dora(tile, player.dora_indicators) and letter != "?" do
            {letter, value * 2}
          else
            {letter, value}
          end
        end)

      groups = letters_to_groups(letters)
      words = score_groups(groups)

      scrabble_total =
        if player.exhaustive_draw_count > 2 or player.ronned do
          0
        else
          words |> Enum.map(fn {_word, score} -> score end) |> Enum.sum()
        end

      result = %{
        letters: letters,
        groups: groups,
        words: words,
        scrabble_total: scrabble_total
      }

      Map.merge(player, result)
    end
  end

  defp score_groups(groups) do
    groups
    |> Enum.flat_map(fn {letters, bonus} ->
      words = find_words(letters)

      for word <- words do
        {_found_word, found_letters, is_valid?} = valid_word?(word)

        if is_valid? do
          {scored_word, score} = letters_to_score(found_letters)
          {scored_word, score + bonus}
        end
      end
      |> Enum.reject(&is_nil/1)
    end)
  end

  defp count_exhaustive_draws_until(state, round_num) do
    state
    |> Enum.take(round_num)
    |> Enum.reduce(0, fn round, acc ->
      if is_exhaustive_draw(round) do
        acc + 1
      else
        0
      end
    end)
  end

  defp is_exhaustive_draw(round) do
    Enum.any?(round, & &1.exhaustive)
  end

  defp discards_to_letters(tiles) do
    for tile <- tiles do
      Map.get(@tile_to_letter, tile, @stop_letter)
    end
  end

  defp letters_to_groups(letters) do
    rows =
      for idx <- 0..2 do
        {row_from_discards(letters, idx), 0}
      end

    columns =
      for idx <- 0..5 do
        {column_from_discards(letters, idx), idx + 1}
      end

    Enum.concat(rows, columns)
  end

  defp row_from_discards(enum, n) do
    enum
    |> Enum.drop(@row_width * n)
    |> Enum.take(@row_width)
  end

  defp column_from_discards(enum, n) do
    indices = n..(@row_width * @column_height)//@row_width

    Enum.reduce_while(indices, [], fn idx, acc ->
      case Enum.at(enum, idx) do
        nil -> {:halt, acc}
        value -> {:cont, acc ++ [value]}
      end
    end)
  end

  defp find_words(letters) do
    letters
    |> Enum.chunk_by(&(&1 == @stop_letter))
    |> Enum.reject(&match?([@stop_letter | _], &1))
  end

  defp valid_word?(letters) do
    word_length = Enum.count(letters)
    wildcard_count = Enum.count(letters, fn {letter, _value} -> letter == "?" end)

    permutations =
      for wildcard <- @alphabet do
        {letters_to_word(letters, wildcard), letters}
      end

    partial_words =
      letters
      |> Enum.chunk_by(fn {letter, _value} -> letter == "?" end)
      |> Enum.map(fn letters -> {letters_to_word(letters, nil), letters} end)

    permutations = Enum.concat(permutations, partial_words)

    words_in_dictionary =
      for {word, letters} <- permutations do
        {word, letters, MapSet.member?(@dictionary, word)}
      end

    {found_word, found_letters, exists?} =
      Enum.find(words_in_dictionary, {nil, nil, false}, fn {_word, _letters, exists?} ->
        exists?
      end)

    is_valid = exists? and word_length > 2 and wildcard_count <= 1
    {found_word, found_letters, is_valid}
  end

  defp letters_to_score(letters) do
    base_value =
      letters
      |> Enum.reject(fn {letter, _value} -> letter == "?" end)
      |> Enum.map(fn {_letter, value} -> value end)
      |> Enum.sum()

    has_wildcard = Enum.any?(letters, fn {letter, _value} -> letter == "?" end)

    multiplier =
      if has_wildcard do
        {_, value} = @wildcard
        value
      else
        1
      end

    total = ceil(base_value * multiplier)
    word = letters_to_word(letters, "?")
    {word, total}
  end

  defp letters_to_word(letters, wildcard) do
    letters
    |> Enum.map(fn
      {"?", _value} -> wildcard
      {letter, _value} -> letter
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join()
  end
end
