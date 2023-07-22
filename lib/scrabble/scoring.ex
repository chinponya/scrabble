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
  @alphabet Enum.map(?a..?z, fn x -> {to_string([x]), 0} end)
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
        if player.exhaustive_draw_count > 1 or player.ronned do
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
    |> Enum.map(fn {group, bonus} ->
      letters = find_valid_word(group)

      if !is_nil(letters) do
        {word, score} = letters_to_score(letters)
        {word, score + bonus}
      end
    end)
    |> Enum.reject(&is_nil/1)
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
        row = row_from_discards(letters, idx)

        row =
          if Enum.count(row) >= @row_width do
            row ++ [@stop_letter]
          else
            row
          end

        {row, 0}
      end

    columns =
      for idx <- 0..5 do
        column = column_from_discards(letters, idx)

        column =
          if Enum.count(column) == @column_height do
            column ++ [@stop_letter]
          else
            column
          end

        {column, idx + 1}
      end

    Enum.concat(rows, columns)
  end

  def row_from_discards(enum, n) do
    to_take = if n == 2, do: 999, else: @row_width

    enum
    |> Enum.drop(@row_width * n)
    |> Enum.take(to_take)
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

  def find_words(letters) do
    letters
    |> Enum.reduce(
      {[], []},
      fn {letter, value}, {current, acc} ->
        if letter == "-" do
          {[], [current | acc]}
        else
          {current ++ [{letter, value}], acc}
        end
      end
    )
    |> then(&elem(&1, 1))
    |> Enum.reverse()
    |> Enum.reject(&Enum.empty?/1)
  end

  def find_valid_word(letters) do
    wildcard_incides =
      letters
      |> Enum.with_index()
      |> Enum.filter(fn {{letter, _value}, _index} -> letter == "?" end)
      |> Enum.map(fn {_, index} -> index end)

    wildcard_incides = if Enum.empty?(wildcard_incides), do: [0], else: wildcard_incides

    groups =
      for wildcard_index <- wildcard_incides do
        for {{letter, value}, index} <- Enum.with_index(letters) do
          cond do
            letter == "?" and Enum.count(wildcard_incides) == 1 ->
              [@stop_letter | @alphabet]

            letter == "?" and index == wildcard_index ->
              @alphabet

            letter == "?" ->
              [@stop_letter]

            true ->
              [{letter, value}]
          end
        end
      end

    permutations = Enum.flat_map(groups, &cartesian_product/1)
    words = Enum.flat_map(permutations, &find_words/1)

    valid_words =
      Enum.filter(words, fn letters ->
        word = letters_to_word(letters)
        Enum.count(letters) > 2 and MapSet.member?(@dictionary, word)
      end)

    valid_words
    |> Enum.sort_by(&Enum.count/1, :desc)
    |> Enum.at(0)
  end

  defp letters_to_score(letters) do
    base_value =
      letters
      |> Enum.reject(fn {letter, _value} -> letter == "?" end)
      |> Enum.map(fn {_letter, value} -> value end)
      |> Enum.sum()

    has_wildcard = Enum.any?(letters, fn {_letter, value} -> value < 1 end)

    multiplier =
      if has_wildcard do
        {_, value} = @wildcard
        value
      else
        1
      end

    total = ceil(base_value * multiplier)
    word = letters_to_word(letters)
    {word, total}
  end

  defp letters_to_word(letters) do
    letters
    |> Enum.map(fn {letter, _value} -> letter end)
    |> Enum.join()
  end

  defp cartesian_product(lists) do
    for group <- lists, reduce: [[]] do
      permutations ->
        for element <- group, permutation <- permutations do
          [element | permutation]
        end
    end
    |> Enum.map(&Enum.reverse/1)
  end
end
