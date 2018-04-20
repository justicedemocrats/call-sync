defmodule CallSync do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(CallSync.Endpoint, []),
      worker(CallSync.SyncConfig, []),
      worker(CallSync.TermCodeConfig, []),
      worker(Livevox.Session, []),
      # worker(
      #   Mongo,
      #   [
      #     [
      #       name: :syncdb,
      #       database: "call-sync",
      #       username: Application.get_env(:call_sync, :syncdb_username),
      #       password: Application.get_env(:call_sync, :syncdb_password),
      #       seeds: Application.get_env(:call_sync, :syncdb_seeds),
      #       port: Application.get_env(:call_sync, :syncdb_port),
      #       pool: DBConnection.Poolboy
      #     ]
      #   ],
      #   id: :syncdb
      # ),
      # worker(
      #   Mongo,
      #   [
      #     [
      #       name: :archivedb,
      #       database: "livevox-archives",
      #       username: Application.get_env(:call_sync, :archivedb_username),
      #       password: Application.get_env(:call_sync, :archivedb_password),
      #       seeds: Application.get_env(:call_sync, :archivedb_seeds),
      #       port: Application.get_env(:call_sync, :archivedb_port),
      #       pool: DBConnection.Poolboy
      #     ]
      #   ],
      #   id: :archivedb
      # ),
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
