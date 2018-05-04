# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :call_sync, CallSync.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "nVL3vv3q5NFyyVHHMBNLghnxRCeWIsm6/fUm18uka70Zr30xOd8eVbjRYrr/j04G",
  render_errors: [view: CallSync.ErrorView, accepts: ~w(json)],
  pubsub: [name: CallSync.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :call_sync, CallSync.Scheduler,
  timezone: "America/New_York",
  jobs: [
    {"*/9 * * * *", {CallSync.TermCodeConfig, :update, []}},
    {"*/8 * * * *", {CallSync.SyncConfig, :update, []}},
    {"0 1  * * * *", {CallSync.SyncManager, :sync_all, []}},
    {"0 5 * * * *", {Archive, :go, []}}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
