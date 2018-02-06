defmodule Sync do
  import ShortMaps
  require Logger

  def sync_all do
    listings = CallSync.AirtableCache.get_all().listings

    listings
    |> Enum.filter(fn {_slug, entry} -> entry["active"] == true end)
    |> Enum.map(fn {slug, _} ->
      Logger.info("Starting sync for #{slug}")
      sync_candidate(slug)
    end)
  end

  def sync_candidate(slug) do
    service_configuration = CallSync.AirtableCache.get_all().configurations[slug]

    listing_configuration =
      ~m(service_names api_key reference_name) = CallSync.AirtableCache.get_all().listings[slug]

    case listing_configuration do
      %{"system" => "csv"} ->
        Sync.Bulk.sync_bulk(slug, service_names, service_configuration)

      %{"strategy" => "all csv"} ->
        Sync.Bulk.sync_bulk(slug, service_names, service_configuration)

      ~m(system api_key service_names strategy) ->
        Sync.Batch.sync_batch(
          slug,
          service_names,
          service_configuration,
          api_key,
          system,
          strategy
        )
    end

    Logger.info("Done!")
  end
end
