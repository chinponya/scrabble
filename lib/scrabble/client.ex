defmodule Scrabble.Client do
  use Soulless.Game.Client
  alias Soulless.Game.Lq
  alias Soulless.Game.Service.Lobby

  def handle_call(:version, _from, state) do
    {:reply, state[:version], state}
  end

  @spec fetch_contest_id_by_share_code(non_neg_integer()) ::
          {:error, :notfound} | {:ok, non_neg_integer()}
  def fetch_contest_id_by_share_code(contest_id) do
    response =
      %Lq.ReqFetchCustomizedContestByContestId{contest_id: contest_id}
      |> Lobby.fetch_customized_contest_by_contest_id()
      |> fetch()

    if response.contest_info do
      {:ok, response.contest_info.unique_id}
    else
      {:error, :notfound}
    end
  end

  def fetch_contest_games(majsoul_contest_id) do
    majsoul_contest_id
    |> fetch_contest_game_ids()
    |> Enum.map(&fetch_game/1)
  end

  @spec fetch_contest_game_ids(non_neg_integer()) :: MapSet.t(String.t())
  def fetch_contest_game_ids(majsoul_contest_id) do
    fetch_contest_game_ids(majsoul_contest_id, nil, MapSet.new())
  end

  defp fetch_contest_game_ids(majsoul_contest_id, index, uuids) do
    Logger.info("Fetching contest #{majsoul_contest_id} games from index: #{index || 0}")
    response =
      %Lq.ReqFetchCustomizedContestGameRecords{
        unique_id: majsoul_contest_id,
        last_index: index || 0
      }
      |> Lobby.fetch_customized_contest_game_records()
      |> fetch()

    new_uuids =
      response.record_list
      |> Enum.map(fn game -> game.uuid end)
      |> MapSet.new()
      |> MapSet.union(uuids)

    cond do
      response.next_index == 0 -> new_uuids
      response.next_index > index && !is_nil(index) -> new_uuids
      Enum.empty?(response.record_list) -> new_uuids
      true -> fetch_contest_game_ids(majsoul_contest_id, response.next_index, new_uuids)
    end
  end

  def fetch_game(game_uuid) do
    Logger.info("Fetching game log #{game_uuid}")
    version = GenServer.call(__MODULE__, :version)

    response =
      %Lq.ReqGameRecord{game_uuid: game_uuid, client_version_string: client_version(version)}
      |> Lobby.fetch_game_record()
      |> fetch()

    if is_nil(response.error) do
      game_data = decode_wrapped_message(response.data)

      game_log =
        if Enum.count(game_data.records) > 0 do
          game_data.records
        else
          game_data.actions
          |> Enum.filter(fn action -> action.type == 1 end)
          |> Enum.map(fn action -> action.result end)
        end
        |> Enum.map(fn result -> decode_wrapped_message(result) end)

      {:ok, {response.head, game_log}}
    else
      {:error, response.error.code}
    end
  end

  defp decode_wrapped_message(wrapper) do
    with {:ok, module} <- Lq.get_module_by_identifier(wrapper.name),
         {:ok, message} <- module.decode(wrapper.data) do
      message
    end
  end

  defp client_version(version) do
    "web-#{version}"
  end
end
