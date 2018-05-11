defmodule CallSync.Reporting do
  import ShortMaps

  @reporting_interval [hours: -12]
  @on_successful_report_fleet Application.get_env(:call_sync, :on_successful_report_fleet)
  @on_failed_report_fleet Application.get_env(:call_sync, :on_failed_report_fleet)

  def record_report(report) do
    ~m(client) = report
    created_at = Timex.now()
    Mongo.insert_one(:syncdb, "reports", ~m(client created_at))
  end

  def all_good? do
    checked_clients =
      CallSync.SyncConfig.get_all().listings
      |> Enum.map(& &1["slug"])

    made_calls =
      Mongo.distinct!(:syncdb, "calls", "client", %{
        "timestamp" => CallSync.Info.within_24_hours()
      })

    required = MapSet.new(checked_clients) |> MapSet.union(MapSet.new(made_calls))

    reports =
      Mongo.distinct!(:syncdb, "reports", "client", %{
        "created_at" => %{"$gt" => Timex.now() |> Timex.shift(@reporting_interval)}
      })

    case MapSet.difference(required, MapSet.new(reports)) do
      [] -> {:ok, required}
      missing -> {:error, missing}
    end
  end

  def panick_if_missing_reports do
    case all_good?() do
      {:ok, sent} -> HTTPotion.post(@on_successful_report_fleet, body: Poison.encode!(~m(sent)))
      {:ok, missing} -> HTTPotion.post(@on_failed_report_fleet, body: Poison.encode!(~m(missing)))
    end
  end
end
