defmodule Livevox.Session do
  use Agent
  defstruct [:id, :expires_at]
  require Logger

  def clientname, do: Application.get_env(:call_sync, :lv_clientname)
  def username, do: Application.get_env(:call_sync, :lv_username)
  def password, do: Application.get_env(:call_sync, :lv_password)

  # State takes the format index
  def start_link do
    Agent.start_link(
      fn ->
        create_session()
      end,
      name: __MODULE__
    )
  end

  def session_id do
    Agent.get_and_update(__MODULE__, fn
      sesh = %Livevox.Session{id: id, expires_at: expires_at} ->
        if Timex.before?(expires_at, Timex.now()) do
          # if expired, renew it
          new = %{id: new_id} = create_session()
          {new_id, new}
        else
          # if not expired, return it and update its expiration
          new = %Livevox.Session{id: id, expires_at: Timex.now() |> Timex.shift(hours: 2)}
          {id, new}
        end

      nil ->
        new = %{id: new_id} = create_session()
        {new_id, new}
    end)
  end

  defp create_session do
    %{body: %{"sessionId" => sessionId}} =
      Livevox.Api.post(
        "session/v6.0/login",
        headers: [no_session: true],
        body: %{userName: username, password: password, clientName: clientname}
      )

    %Livevox.Session{id: sessionId, expires_at: Timex.now() |> Timex.shift(hours: 2)}
  end
end
