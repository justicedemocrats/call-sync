defmodule Sync do
  import ShortMaps
  require Logger

  @batch_size 10

  def sync_all do
    listings = CallSync.AirtableCache.get_all().listings

    Enum.map(listings, fn {slug, _} ->
      Logger.info("Starting sync for #{slug}")
    end)
  end

  def sync_candidate(slug) do
    service_configuration = CallSync.AirtableCache.get_all().configurations[slug]

    listing_configuration =
      ~m(service_ids api_key reference_name) = CallSync.AirtableCache.get_all().listings[slug]

    case listing_configuration do
      %{"system" => "csv"} ->
        Sync.Bulk.sync_bulk(slug, service_ids, service_configuration)

      %{"system" => "van", "api_key" => api_key, "service_ids" => service_ids} ->
        Sync.Batch.sync_batch(slug, service_ids, service_configuration, api_key)
    end
  end

  def write_result(result, call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => %{sync_status: result}})
  end
end
