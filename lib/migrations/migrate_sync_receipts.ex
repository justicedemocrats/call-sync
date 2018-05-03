defmodule CallSync.MigrateSyncReceipts do
  import ShortMaps
  require Logger

  @report_interval 100

  def go do
    timerange = %{
      "$gt" => Timex.now() |> Timex.shift(hours: -8) |> Timex.shift(days: -3),
      "$lt" => Timex.now() |> Timex.shift(hours: -8) |> Timex.shift(days: -2)
    }

    Mongo.find(
      :productiondb,
      "calls",
      %{"sync_status" => %{"$exists" => true}, "timestamp" => timerange},
      pool: DBConnection.Poolboy,
      timeout: :infinity
    )
    |> Stream.with_index()
    |> Stream.filter(skip(3700))
    |> Flow.from_enumerable(min_demand: 5, max_demand: 10, stages: 20)
    |> Flow.map(&update_progress/1)
    |> Flow.each(&transfer_sync_status/1)
    |> Flow.run()
  end

  def skip(n) do
    fn {_, idx} ->
      idx > n
    end
  end

  def update_progress({line, idx}) do
    if rem(idx, @report_interval) == 0 do
      Logger.info("Did #{idx}")
    end

    line
  end

  def transfer_sync_status(call = ~m(phone_dialed timestamp)) do
    query = %{
      "phone_dialed" => phone_dialed,
      "timestamp" => %{
        "$gt" => Timex.shift(timestamp, minutes: -10),
        "$lt" => Timex.shift(timestamp, minutes: 10)
      }
    }

    sync_info = Map.take(call, ~w(sync_status receipt synced_at))

    {:ok, match_count} =
      Mongo.count(
        :productiondb,
        "calls",
        query,
        pool: DBConnection.Poolboy
      )

    if match_count != 1 do
      IO.inspect(call)
      Process.exit(self())
    end

    Mongo.update_one(
      :productiondb,
      "calls",
      query,
      %{"$set" => sync_info},
      pool: DBConnection.Poolboy
    )
  end
end
