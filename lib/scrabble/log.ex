defmodule Scrabble.State do
  alias Soulless.Game.Lq

  def from_log(%Lq.RecordGame{} = game_head, game_events) do
    state = initial_state_from_game_log(game_head)

    events_by_round =
      game_events
      |> Enum.chunk_by(&match?(%Lq.RecordNewRound{}, &1))
      |> Enum.reject(&match?([%Lq.RecordNewRound{}], &1))

    for events <- events_by_round do
      Enum.reduce(events, state, &event_to_discards/2)
    end
  end

  defp initial_state_from_game_log(%Lq.RecordGame{} = game_head) do
    for account <- game_head.accounts do
      player_result = get_by_seat(game_head.result.players, account.seat)

      %{
        nickname: account.nickname,
        seat: account.seat,
        score: round(player_result.total_point / 1000),
        points: player_result.part_point_1,
        discards: [],
        ronned: false,
        exhaustive: false
      }
    end
  end

  defp event_to_discards(%Lq.RecordDiscardTile{} = event, state) do
    add_discard(state, event.seat, event.tile)
  end

  defp event_to_discards(%Lq.RecordChiPengGang{} = event, state) do
    tiles = Enum.zip(event.tiles, event.froms)
    {called_tile, target} = Enum.find(tiles, fn {_tile, from} -> from != event.seat end)
    remove_last_discard(state, target, called_tile)
  end

  defp event_to_discards(%Lq.RecordHule{} = event, state) do
    first_win = Enum.at(event.hules, 0)

    if first_win.zimo do
      state
    else
      # HACK probably breaks on pao
      target = Enum.find_index(event.delta_scores, &(&1 == Enum.min(event.delta_scores)))
      update_by_seat(state, target, fn player -> %{player | ronned: true} end)
    end
  end

  defp event_to_discards(%Lq.RecordNoTile{} = _event, state) do
    for player <- state do
      %{player | exhaustive: true}
    end
  end

  defp event_to_discards(_event, state) do
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
end
