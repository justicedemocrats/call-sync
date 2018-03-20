defmodule Sync.Bulk do
  import ShortMaps

  def sync_bulk(slug, service_names, config, progress_fn) do
    bulk_results_stream = stream_all_unsynced(service_names)

    ~m(file_url aggregated_results) =
      Sync.Csv.result_stream_to_csv(bulk_results_stream, slug, config, progress_fn)

    total = Sync.Info.value_sum(aggregated_results)
    {slug, "all csv", ~m(file_url aggregated_results total)}
  end

  def stream_all_unsynced(service_names) do
    Db.find(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status" => %{"$exists" => false}})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}}),
      sort: %{"timestamp" => 1}
    )
  end
end
