use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# command from your terminal:
#
#     openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" -keyout priv/server.key -out priv/server.pem
#
# The `http:` config below can be replaced with:
# https: [port: 4000, keyfile: "priv/server.key", certfile: "priv/server.pem"],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.
config :call_sync, CallSync.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

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

config :call_sync, application_name: System.get_env("VAN_APP_NAME")
