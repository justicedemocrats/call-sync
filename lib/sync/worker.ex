defmodule Sync.Worker do
  use Honeydew.Progress
  import ShortMaps
  require Logger

  def sync_candidate(slug) do
    service_configuration = CallSync.AirtableCache.get_all().configurations[slug]

    listing_configuration =
      ~m(service_names client_name) = CallSync.AirtableCache.get_all().listings[slug]

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
