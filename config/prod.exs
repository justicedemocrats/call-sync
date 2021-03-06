use Mix.Config

# For production, we configure the host to read the PORT
# from the system environment. Therefore, you will need
# to set PORT=80 before running your server.
#
# You should also configure the url host to something
# meaningful, we use this information when generating URLs.
#
# Finally, we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the mix phoenix.digest task
# which you typically run after static files are built.
config :call_sync, CallSync.Endpoint,
  http: [:inet6, port: {:system, "PORT"}],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Do not print debug messages in production
config :logger, level: :info

# Update secret
config :call_sync, update_secret: "${UPDATE_SECRET}"

config :call_sync,
  syncdb_username: "${SYNCDB_USERNAME}",
  syncdb_password: "${SYNCDB_PASSWORD}",
  syncdb_seeds: [
    "${SYNCDB_SEED_1}",
    "${SYNCDB_SEED_2}"
  ],
  syncdb_port: "${SYNCDB_PORT}"

config :call_sync,
  archivedb_username: "${ARCHIVEDB_USERNAME}",
  archivedb_password: "${ARCHIVEDB_PASSWORD}",
  archivedb_seeds: [
    "${ARCHIVEDB_SEED_1}",
    "${ARCHIVEDB_SEED_2}"
  ],
  archivedb_port: "${ARCHIVEDB_PORT}"

config :call_sync,
  productiondb_username: "${PRODUCTIONDB_USERNAME}",
  productiondb_password: "${PRODUCTIONDB_PASSWORD}",
  productiondb_seeds: [
    "${PRODUCTIONDB_SEED_1}",
    "${PRODUCTIONDB_SEED_2}"
  ],
  productiondb_port: "${PRODUCTIONDB_PORT}"

config :rollbax,
  access_token: "${ROLLBAR_ACCESS_TOKEN}",
  environment: "production"

config :call_sync,
  sync_airtable_key: System.get_env("SYNC_AIRTABLE_KEY"),
  sync_airtable_base: System.get_env("SYNC_AIRTABLE_BASE"),
  sync_airtable_table_name: System.get_env("SYNC_AIRTABLE_TABLE_NAME"),
  term_code_airtable_key: System.get_env("TERM_CODE_AIRTABLE_KEY"),
  term_code_airtable_base: System.get_env("TERM_CODE_AIRTABLE_BASE"),
  term_code_airtable_table_name: System.get_env("TERM_CODE_AIRTABLE_TABLE_NAME"),
  secret: "${UPDATE_SECRET}"

config :call_sync,
  lv_access_token: "${LIVEVOX_ACCESS_TOKEN}",
  lv_clientname: "${LIVEVOX_CLIENT_NAME}",
  lv_username: "${LIVEVOX_USERNAME}",
  lv_password: "${LIVEVOX_PASSWORD}"

config :ex_aws,
  access_key_id: "${AWS_ACCESS_KEY_ID}",
  secret_access_key: "${AWS_SECRET_ACCESS_KEY}",
  region: "${AWS_BUCKET_REGION}"

config :call_sync, aws_bucket_name: "${AWS_BUCKET_NAME}"
config :call_sync, application_name: "${VAN_APP_NAME}"

config :call_sync,
  report_success_url: "${REPORT_SUCCESS_URL}",
  report_error_url: "${REPORT_FAILURE_URL}",
  zapier_hook_url: "${ZAPIER_HOOK_URL}",
  second_zapier_hook_url: "${SECOND_ZAPIER_HOOK_URL}",
  login_management_url: "${LOGIN_MANAGEMENT_URL}",
  upload_complete_hook: "${UPLOAD_COMPLETE_HOOK}",
  upload_failed_hook: "${UPLOAD_FAILED_HOOK}",
  on_successful_report_fleet: "${ON_SUCCESSFUL_REPORT_FLEET}",
  on_failed_report_fleet: "${ON_FAILED_REPORT_FLEET}"
