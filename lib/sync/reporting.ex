defmodule CallSync.Reporting do
  import ShortMaps

  @reporting_interval [hours: -12]
  @on_successful_report_fleet Application.get_env(:call_sync, :on_successful_report_fleet)
  @on_failed_report_fleet Application.get_env(:call_sync, :on_failed_report_fleet)

  def record_report(~m(client contents)) do
    created_at = Timex.now()

    Mongo.insert_one(
      :syncdb,
      "reports",
      ~m(client created_at contents),
      pool: DBConnection.Poolboy
    )
  end

  def all_good? do
    checked_clients =
      CallSync.SyncConfig.get_all().listings
      |> Enum.filter(fn {_, ~m(active)} -> active end)
      |> Enum.map(fn {s, _} -> s end)

    made_calls =
      Mongo.distinct!(
        :syncdb,
        "calls",
        "client",
        CallSync.Info.within_24_hours(),
        pool: DBConnection.Poolboy,
        timeout: 100_000
      )

    required = MapSet.new(checked_clients) |> MapSet.union(MapSet.new(made_calls))

    reports =
      Mongo.distinct!(
        :syncdb,
        "reports",
        "client",
        %{
          "created_at" => %{"$gt" => Timex.now() |> Timex.shift(@reporting_interval)}
        },
        pool: DBConnection.Poolboy,
        timeout: 100_000
      )

    case MapSet.difference(required, MapSet.new(reports)) do
      [] -> {:ok, required}
      missing -> {:error, missing}
    end
  end

  def panick_if_missing_reports do
    case all_good?() do
      {:ok, sent} ->
        HTTPotion.post(@on_successful_report_fleet, body: Poison.encode!(~m(sent)))

      {:error, missing} ->
        HTTPotion.post(@on_failed_report_fleet, body: Poison.encode!(~m(missing)))
    end
  end
end
