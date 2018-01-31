defmodule Sync do
  import ShortMaps

  @batch_size 10

  def sync_candidate({slug, ~m(service_ids api_key reference_name)}) do
    listing_configuration = CallSync.AirtableCache.get_all().listings[slug]
    service_configuration = CallSync.AirtableCache.get_all().configurations[slug]

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
