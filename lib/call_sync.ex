defmodule CallSync do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(CallSync.Endpoint, []),
      worker(CallSync.AirtableCache, []),
      worker(Livevox.Session, [])
    ]

    IO.inspect(Application.get_all_env(:livevox))

    opts = [strategy: :one_for_one, name: CallSync.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    CallSync.Endpoint.config_change(changed, removed)
    :ok
  end
end
