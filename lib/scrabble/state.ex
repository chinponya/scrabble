defmodule Scrabble.State do
  alias Soulless.Game.Lq

  def from_log(%Lq.RecordGame{} = game_head, game_events) do
    game_events
    |> Enum.reduce([], fn event, acc ->
      case event do
        %Lq.RecordNewRound{} ->
          round = initial_state_from_game_log(game_head)
          new_round = convert_event(event, round)
          List.insert_at(acc, 0, new_round)

        _ ->
          [round | remaining] = acc
          new_round = convert_event(event, round)
          [new_round | remaining]
      end
    end)
    |> Enum.reverse()
  end

  defp initial_state_from_game_log(%Lq.RecordGame{} = game_head) do
    for account <- game_head.accounts do
      player_result = get_by_seat(game_head.result.players, account.seat)

      %{
        nickname: account.nickname,
        seat: account.seat,
        score: Float.round(player_result.total_point / 1000, 1),
        points: player_result.part_point_1,
        discards: [],
        ronned: false,
        exhaustive: false,
        dora_indicators: []
      }
    end
  end

  defp convert_event(%Lq.RecordNewRound{} = event, state) do
    add_doras(state, event.doras)
  end

  defp convert_event(%Lq.RecordDiscardTile{} = event, state) do
    new_state =
      if !is_nil(event.doras) && !Enum.empty?(event.doras) do
        add_doras(state, event.doras)
      else
        state
      end

    add_discard(new_state, event.seat, event.tile)
  end

  defp convert_event(%Lq.RecordDealTile{} = event, state) do
    if !is_nil(event.doras) && !Enum.empty?(event.doras) do
      add_doras(state, event.doras)
    else
      state
    end
  end

  defp convert_event(%Lq.RecordChiPengGang{} = event, state) do
    tiles = Enum.zip(event.tiles, event.froms)
    {called_tile, target} = Enum.find(tiles, fn {_tile, from} -> from != event.seat end)
    remove_last_discard(state, target, called_tile)
  end

  defp convert_event(%Lq.RecordHule{} = event, state) do
    first_win = Enum.at(event.hules, 0)

    if first_win.zimo do
      state
    else
      # HACK probably breaks on pao
      target = Enum.find_index(event.delta_scores, &(&1 == Enum.min(event.delta_scores)))
      update_by_seat(state, target, fn player -> %{player | ronned: true} end)
    end
  end

  defp convert_event(%Lq.RecordNoTile{} = _event, state) do
    for player <- state do
      %{player | exhaustive: true}
    end
  end

  defp convert_event(_event, state) do
    state
  end

  defp get_by_seat(state, seat) do
    Enum.find(state, &(&1.seat == seat))
  end

  defp update_by_seat(state, seat, fun) do
    idx = Enum.find_index(state, &(&1.seat == seat))
    List.update_at(state, idx, &apply(fun, [&1]))
  end

  defp add_discard(state, seat, tile) do
    update_by_seat(state, seat, fn player -> %{player | discards: player.discards ++ [tile]} end)
  end

  defp remove_last_discard(state, seat, tile) do
    update_by_seat(state, seat, fn player ->
      to_remove = Enum.at(player.discards, -1)

      if tile != to_remove do
        raise "last discarded tile #{to_remove} by seat #{seat} doesn't match the called tile #{tile}"
      end

      %{player | discards: List.delete_at(player.discards, -1)}
    end)
  end

  defp add_doras(state, doras) do
    for player <- state do
      %{player | dora_indicators: doras}
    end
  end
end
