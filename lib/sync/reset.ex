defmodule Sync.Reset do
  import ShortMaps

  def candidate(slug) do
    ~m(service_names) = CallSync.AirtableCache.get_all().listings[slug]

    Db.update(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"service_name" => %{"$in" => service_names}}),
      %{"$unset" => %{"sync_status" => 1}}
    )
  end

  def candidate_errors(slug) do
    ~m(service_names) = CallSync.AirtableCache.get_all().listings[slug]

    Db.update(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
      |> Map.merge(%{"sync_status" => %{"$in" => ["attempted_error", "unattempted_error"]}}),
      %{"$unset" => %{"sync_status" => 1}}
    )
  end

  def count_candidate(slug) do
    ~m(service_names) = CallSync.AirtableCache.get_all().listings[slug]

    Db.count(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
    )
  end
end
