use Mix.Config

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
  syncdb_username: System.get_env("SYNCDB_USERNAME"),
  syncdb_password: System.get_env("SYNCDB_PASSWORD"),
  syncdb_seeds: [
    System.get_env("SYNCDB_SEED_1"),
    System.get_env("SYNCDB_SEED_2")
  ],
  syncdb_port: System.get_env("SYNCDB_PORT")

config :call_sync,
  archivedb_username: System.get_env("ARCHIVEDB_USERNAME"),
  archivedb_password: System.get_env("ARCHIVEDB_PASSWORD"),
  archivedb_seeds: [
    System.get_env("ARCHIVEDB_SEED_1"),
    System.get_env("ARCHIVEDB_SEED_2")
  ],
  archivedb_port: System.get_env("ARCHIVEDB_PORT")

config :call_sync,
  productiondb_username: System.get_env("PRODUCTIONDB_USERNAME"),
  productiondb_password: System.get_env("PRODUCTIONDB_PASSWORD"),
  productiondb_seeds: [
    System.get_env("PRODUCTIONDB_SEED_1"),
    System.get_env("PRODUCTIONDB_SEED_2")
  ],
  productiondb_port: System.get_env("PRODUCTIONDB_PORT")

config :rollbax,
  access_token: System.get_env("ROLLBAR_ACCESS_TOKEN"),
  environment: "production"

config :call_sync,
  sync_airtable_key: System.get_env("SYNC_AIRTABLE_KEY"),
  sync_airtable_base: System.get_env("SYNC_AIRTABLE_BASE"),
  sync_airtable_table_name: System.get_env("SYNC_AIRTABLE_TABLE_NAME"),
  term_code_airtable_key: System.get_env("TERM_CODE_AIRTABLE_KEY"),
  term_code_airtable_base: System.get_env("TERM_CODE_AIRTABLE_BASE"),
  term_code_airtable_table_name: System.get_env("TERM_CODE_AIRTABLE_TABLE_NAME"),
  secret: "secret"

config :call_sync,
  lv_access_token: System.get_env("LIVEVOX_ACCESS_TOKEN"),
  lv_clientname: System.get_env("LIVEVOX_CLIENT_NAME"),
  lv_username: System.get_env("LIVEVOX_USERNAME"),
  lv_password: System.get_env("LIVEVOX_PASSWORD")

config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_BUCKET_REGION")

config :call_sync, aws_bucket_name: System.get_env("AWS_BUCKET_NAME")
config :call_sync, application_name: System.get_env("VAN_APP_NAME")

config :call_sync,
  report_success_url: System.get_env("REPORT_SUCCESS_URL"),
  report_error_url: System.get_env("REPORT_FAILURE_URL"),
  zapier_hook_url: System.get_env("ZAPIER_HOOK_URL"),
  second_zapier_hook_url: System.get_env("SECOND_ZAPIER_HOOK_URL"),
  login_management_url: System.get_env("LOGIN_MANAGEMENT_URL"),
  upload_complete_hook: System.get_env("UPLOAD_COMPLETE_HOOK"),
  upload_failed_hook: System.get_env("UPLOAD_FAILED_HOOK")
