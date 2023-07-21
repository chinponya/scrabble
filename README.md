# Scrabble

Scoring shitcode for the [Scrabble Mahjong tourney](https://docs.google.com/document/d/1Vk4ccTNB1AxzI7mACa1aOu0_h66PZYdnrgySDTMqfAI/edit)

Requires [Elixir 1.14](https://elixir-lang.org/install.html) to run.

Before you use this, you have to obtain your MJS uid and token. This process is described [in the Soulless library repo](https://github.com/chinponya/soulless#configuration).

After that, set your credentials via environment variables:
```
export MAJSOUL_UID="0000000"
export MAJSOUL_TOKEN="effeffeffeffeffeffeffeffeffeff"
export MAJSOUL_TOKEN_KIND="transient"
```

There's no interface yet. This tool can only be used from the REPL, like so:
```
$ iex -S mix
iex(1)> Scrabble.contest_summary_to_csv_file(165201, "summary.csv")
iex(2)> Scrabble.contest_to_csv_file(165201, "full.csv")
iex(3)> Scrabble.game_to_csv_file("230721-2cc15589-bc9d-435b-a2d7-8a1e95cf9fd5", "game.csv")
```