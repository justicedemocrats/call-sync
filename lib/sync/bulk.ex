defmodule CallSync.Bulk do
  import ShortMaps

  def sync_bulk(slug, district, config, progress_fn) do
    bulk_results_stream = stream_all_unsynced(district)

    ~m(file_url aggregated_results) =
      CallSync.Csv.result_stream_to_csv(bulk_results_stream, slug, config, progress_fn)

    total = CallSync.Info.value_sum(aggregated_results)
    {slug, "all csv", ~m(file_url aggregated_results total)}
  end

  def stream_all_unsynced(district) do
    Db.find(
      "calls",
      CallSync.Info.within_24_hours()
      |> Map.merge(%{"sync_status" => %{"$exists" => false}})
      |> Map.merge(%{"district" => district}),
      sort: %{"timestamp" => 1}
    )
  end
end
