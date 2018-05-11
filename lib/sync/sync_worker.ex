defmodule CallSync.SyncWorker do
  use Honeydew.Progress
  import ShortMaps
  require Logger

  def report_success_url, do: Application.get_env(:call_sync, :report_success_url)
  def report_error_url, do: Application.get_env(:call_sync, :report_error_url)

  def sync_candidate(slug) do
    try do
      contents = do_sync_candidate(slug)

      CallSync.Reporting.record_report(%{"client" => slug, "contents" => contents})

      HTTPotion.post(
        report_success_url() |> IO.inspect(),
        body: Poison.encode!(%{"timestamp" => DateTime.utc_now(), "slug" => slug})
      )
    rescue
      error ->
        timestamp = DateTime.utc_now()
        HTTPotion.post(report_error_url(), body: Poison.encode!(~m(error timestamp slug)))
    end
  end

  def do_sync_candidate(slug) do
    service_configuration = CallSync.SyncConfig.get_all().configurations[slug]

    listing_configuration =
      ~m(district_abbreviation) = CallSync.SyncConfig.get_all().listings[slug]

    Logger.info("Starting #{slug}")
    monitor = Process.get(:monitor)

    progress_fn = fn num ->
      :ok = GenServer.call(monitor, {:progress, num})
    end

    {slug, strategy, data} =
      case listing_configuration do
        %{"system" => "csv"} ->
          # TODO
          CallSync.Bulk.sync_bulk(slug, district_abbreviation, service_configuration, progress_fn)

        %{"strategy" => "all csv"} ->
          # TODO
          CallSync.Bulk.sync_bulk(slug, district_abbreviation, service_configuration, progress_fn)

        ~m(system api_key district_abbreviation strategy) ->
          # TODO
          CallSync.Batch.sync_batch(
            slug,
            district_abbreviation,
            service_configuration,
            api_key,
            system,
            strategy,
            progress_fn
          )
      end

    # TODO
    rows = CallSync.AgentData.from(district_abbreviation)
    {agent_file_url, agent_count} = CallSync.AgentData.upload_file(slug, rows)
    contents = Notifier.send(slug, strategy, Map.merge(data, ~m(agent_file_url agent_count)))
    Logger.info("Done!")
    contents
  end
end
