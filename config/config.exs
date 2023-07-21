import Config

config :soulless,
  uid: System.get_env("MAJSOUL_UID"),
  access_token: System.get_env("MAJSOUL_TOKEN"),
  token_kind: System.get_env("MAJSOUL_TOKEN_KIND", "permanent") |> String.to_atom(),
  region: :en
