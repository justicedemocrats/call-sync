defmodule CallSync do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(CallSync.Endpoint, []),
      worker(CallSync.AirtableCache, []),
      worker(Livevox.Session, []),
      worker(
        Mongo,
        [
          [
            name: :mongo,
            database: "livevox",
            username: Application.get_env(:call_sync, :mongodb_username),
            password: Application.get_env(:call_sync, :mongodb_password),
            seeds: Application.get_env(:call_sync, :mongodb_seeds),
            port: Application.get_env(:call_sync, :mongodb_port),
            pool: DBConnection.Poolboy
          ]
        ],
        id: :mongo
      ),
      worker(
        Mongo,
        [
          [
            name: :archives,
            database: "livevox-archives",
            username: Application.get_env(:call_sync, :backupdb_username),
            password: Application.get_env(:call_sync, :backupdb_password),
            seeds: Application.get_env(:call_sync, :backupdb_seeds),
            port: Application.get_env(:call_sync, :backupdb_port)
          ]
        ],
        id: :archives
      ),
      worker(CallSync.Scheduler, []),
      Honeydew.queue_spec(:queue),
      Honeydew.worker_spec(:queue, Sync.Worker, num: 1)
    ]

    opts = [strategy: :one_for_one, name: CallSync.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    CallSync.Endpoint.config_change(changed, removed)
    :ok
  end
end
