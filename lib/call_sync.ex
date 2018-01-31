defmodule CallSync do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(CallSync.Endpoint, []),
      worker(CallSync.AirtableCache, []),
      worker(Livevox.Session, []),
      worker(Mongo, [
        [
          name: :mongo,
          database: "livevox",
          username: Application.get_env(:call_sync, :mongodb_username),
          password: Application.get_env(:call_sync, :mongodb_password),
          hostname: Application.get_env(:call_sync, :mongodb_hostname),
          port: Application.get_env(:call_sync, :mongodb_port),
          pool: DBConnection.Poolboy
        ]
      ])
    ]

    opts = [strategy: :one_for_one, name: CallSync.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    CallSync.Endpoint.config_change(changed, removed)
    :ok
  end
end
