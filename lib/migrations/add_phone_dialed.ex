defmodule Migrations.AddPhoneDialed do
  import ShortMaps

  def go do
    Db.find("calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"phone_dialed" => %{"$exists" => false}})
    )
    |> Stream.map(fn doc = ~m(id) ->
      [phone_dialed, _] = String.split(id, "-")
      IO.puts phone_dialed
      Db.update("calls", ~m(id), %{"$set" => ~m(phone_dialed)})
    end)
    |> Enum.to_list()
    |> length()
  end
end
