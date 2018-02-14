defmodule Sync.Reset do
  import ShortMaps

  def candidate(slug) do
    service_configuration = CallSync.AirtableCache.get_all().configurations[slug]

    listing_configuration =
      ~m(service_names api_key reference_name) = CallSync.AirtableCache.get_all().listings[slug]

    Db.update("calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"service_name" => %{"$in" => service_names}}),
      %{"$unset" => %{"sync_status" => 1}}
    )
  end
end
