use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :call_sync, CallSync.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Update secret
config :call_sync, update_secret: System.get_env("UPDATE_SECRET")

config :call_sync,
  mongodb_username: System.get_env("MONGO_USERNAME"),
  mongodb_hostname: System.get_env("MONGO_HOSTNAME"),
  mongodb_password: System.get_env("MONGO_PASSWORD"),
  mongodb_port: System.get_env("MONGO_PORT")

config :rollbax,
  access_token: System.get_env("ROLLBAR_ACCESS_TOKEN"),
  environment: "production"

config :call_sync,
  airtable_key: System.get_env("AIRTABLE_KEY"),
  airtable_base: System.get_env("AIRTABLE_BASE"),
  airtable_table_name: System.get_env("AIRTABLE_TABLE_NAME"),
  secret: "secret"

config :livevox,
  access_token: System.get_env("LIVEVOX_ACCESS_TOKEN"),
  clientname: System.get_env("LIVEVOX_CLIENT_NAME"),
  username: System.get_env("LIVEVOX_USERNAME"),
  password: System.get_env("LIVEVOX_PASSWORD")

config :call_sync, application_name: System.get_env("VAN_APP_NAME")
