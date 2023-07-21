defmodule Scrabble.Client do
  use Soulless.Game.Client
  alias Soulless.Game.Lq
  alias Soulless.Game.Service.Lobby

  def handle_call(:version, _from, state) do
    {:reply, state[:version], state}
  end

  def fetch_game(game_uuid) do
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
