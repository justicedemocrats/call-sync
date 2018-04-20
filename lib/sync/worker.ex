defmodule CallSync.Worker do
  use Honeydew.Progress
  import ShortMaps
  require Logger

  def report_success_url, do: Application.get_env(:call_sync, :report_success_url)
  def report_error_url, do: Application.get_env(:call_sync, :report_error_url)

  def sync_candidate(slug) do
    try do
      do_sync_candidate(slug)

      HTTPotion.post(
        report_success_url() |> IO.inspect(),
        body: Poison.encode!(%{"timestamp" => DateTime.utc_now(), "slug" => slug})
      )
    rescue
      e ->
        error = e.message
        timestamp = DateTime.utc_now()
        HTTPotion.post(report_error_url(), body: Poison.encode!(~m(error timestamp slug)))
    end
  end

  def do_sync_candidate(slug) do
    service_configuration = CallSync.AirtableCache.get_all().configurations[slug]

    listing_configuration = ~m(service_names) = CallSync.AirtableCache.get_all().listings[slug]

    Logger.info("Starting #{slug}")
    monitor = Process.get(:monitor)

    progress_fn = fn num ->
      :ok = GenServer.call(monitor, {:progress, num})
    end

    {slug, strategy, data} =
      case listing_configuration do
        %{"system" => "csv"} ->
          Sync.Bulk.sync_bulk(slug, service_names, service_configuration, progress_fn)

        %{"strategy" => "all csv"} ->
          Sync.Bulk.sync_bulk(slug, service_names, service_configuration, progress_fn)

        ~m(system api_key service_names strategy) ->
          Sync.Batch.sync_batch(
            slug,
            service_names,
            service_configuration,
            api_key,
            system,
            strategy,
            progress_fn
          )
      end

    rows = Sync.AgentData.from(service_names)
    {agent_file_url, agent_count} = Sync.AgentData.upload_file(slug, rows)

    Notifier.send(slug, strategy, Map.merge(data, ~m(agent_file_url agent_count)))

    Logger.info("Done!")
  end
end
