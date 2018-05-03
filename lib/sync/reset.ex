defmodule CallSync.Reset do
  import ShortMaps

  def candidate(slug) do
    ~m(district_abbreviation) = CallSync.SyncConfig.get_all().listings[slug]

    Db.update(
      "calls",
      CallSync.Info.within_24_hours()
      |> Map.merge(%{"district" => district_abbreviation}),
      %{"$unset" => %{"sync_status" => 1}}
    )
  end

  def candidate_errors(slug) do
    ~m(district_abbreviation) = CallSync.SyncConfig.get_all().listings[slug]

    Db.update(
      "calls",
      CallSync.Info.within_24_hours()
      |> Map.merge(%{"district" => district_abbreviation})
      |> Map.merge(%{"sync_status" => %{"$in" => ["attempted_error", "unattempted_error"]}}),
      %{"$unset" => %{"sync_status" => 1}}
    )
  end

  def count_candidate_errors(slug) do
    ~m(district_abbreviation) = CallSync.SyncConfig.get_all().listings[slug]

    Db.count(
      "calls",
      CallSync.Info.within_24_hours()
      |> Map.merge(%{"district" => district_abbreviation})
      |> Map.merge(%{"sync_status" => %{"$in" => ["attempted_error", "unattempted_error"]}})
    )
  end

  def count_candidate(slug) do
    ~m(district_abbreviation) = CallSync.SyncConfig.get_all().listings[slug]

    Db.count(
      "calls",
      CallSync.Info.within_24_hours()
      |> Map.merge(%{"district" => district_abbreviation})
    )
  end
end
