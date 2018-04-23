defmodule Sync.Batch do
  require Logger
  import ShortMaps

  @batch_size 5

  # Sync @batch_size results for the service in parallel, and record
  # If we're done (fetch_sync_bath_for returned no unsyced calls)
  #   -> upload the queued for csvs
  #   -> send off the report
  # Otherwise
  #   -> recurse!
  def sync_batch(
        slug,
        service_names,
        service_configuration,
        api_key,
        mode,
        strategy,
        progress_fn,
        done \\ 0
      ) do
    Logger.info("Doing batch")

    batch_done =
      fetch_sync_batch_for(service_names)
      |> Enum.map(fn call -> task_sync_call(call, service_configuration, api_key, mode) end)
      |> Enum.map(fn t -> Task.await(t, 30_000) end)

    progress_fn.(done + @batch_size)
    Logger.info("Did batch")

    if length(batch_done) == 0 do
      %{"aggregated_results" => csv_aggregated_results, "file_url" => file_url} =
        case strategy do
          "hybrid" -> upload_queued(slug, service_names, service_configuration)
          _ -> %{"aggregated_results" => nil, "file_url" => nil}
        end

      [aggregated_results, success_count, error_count] =
        [
          Task.async(fn -> fetch_aggregated_results(service_names, service_configuration) end),
          Task.async(fn -> get_success_count(service_names) end),
          Task.async(fn -> get_error_count(service_names) end)
        ]
        |> Enum.map(&Task.await(&1, 1_000_000))

      total = Sync.Info.value_sum(aggregated_results)
      csv_total = Sync.Info.value_sum(csv_aggregated_results)

      {slug, strategy, ~m(
          aggregated_results success_count error_count
          csv_aggregated_results file_url total csv_total
        )}
    else
      sync_batch(
        slug,
        service_names,
        service_configuration,
        api_key,
        mode,
        strategy,
        progress_fn,
        done + @batch_size
      )
    end
  end

  def fetch_sync_batch_for(service_names) do
    query =
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status" => %{"$exists" => false}})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})

    [batch, {:ok, count}] =
      [
        Task.async(fn ->
          Db.find(
            "calls",
            query,
            sort: %{"timestamp" => 1},
            limit: @batch_size
          )
          |> Enum.to_list()
        end),
        Task.async(fn -> Db.count("calls", query) end)
      ]
      |> Enum.map(&Task.await/1)

    Logger.info("#{count} left")
    batch
  end

  # --------------------- --------------------- ---------------------
  # -------------------- Sync an individual call --------------------
  # --------------------- --------------------- ---------------------
  def task_sync_call(call, configuration, api_key, mode) do
    Task.async(fn -> sync_call(call, configuration, api_key, mode) end)
  end

  def sync_call(call, configuration, api_key, mode) do
    send_out(call, configuration, api_key, mode)
    |> write_result(call)
  end

  def send_out(call, config, api_key, mode) do
    mark_started(call)

    with {:ok, body} <- configure_body(call, config),
         {:ok, ~m(id)} <- Sync.Info.fetch_voter_id(call),
         {:ok, ~m(identifiers)} <- Van.record_canvass(id, body, api_key, mode) do
      sync_status = "finished"
      receipt = List.first(identifiers)
      synced_at = DateTime.utc_now()
      ~m(sync_status receipt synced_at)
    else
      {:error, flags} ->
        flags

      {:other, flags} ->
        flags

      {:ok, error} ->
        sync_status = "attempted_error"
        synced_at = DateTime.utc_now()
        ~m(sync_status error synced_at)
    end
  end

  def mark_started(call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => %{sync_status: "in_progress"}})
  end

  def configure_body(call = ~m(full_on_screen_result), config) do
    fosr = String.trim(full_on_screen_result)

    if Map.has_key?(config, fosr) do
      do_configure_body(call, config)
    else
      sync_status = "unattempted_error"
      error = "missing config for #{full_on_screen_result}"
      synced_at = DateTime.utc_now()
      {:error, ~m(sync_status error synced_at)}
    end
  end

  def do_configure_body(call, configuration) do
    key = String.trim(call["full_on_screen_result"])
    result_map = configuration[key]

    status_code = Map.get(result_map, "result_code")
    add_tags = Map.get(result_map, "tags")
    ~m(success should_sync csv_only) = result_map

    add_answers =
      Map.get(result_map, "qr_pairs")
      |> Enum.map(fn {q, r} ->
        %{"question" => "https://osdi.ngpvan.com/api/v1/questions/#{q}", "responses" => [r]}
      end)

    cond do
      success != true and success != false ->
        error =
          "invalid configuration for #{key}: success is #{success}, and must be true or false"

        synced_at = DateTime.utc_now()
        sync_status = "unattempted_error"
        {:error, ~m(sync_status error synced_at)}

      success == false and (status_code == nil or status_code == "") ->
        error =
          "invalid configuration for #{key}: when success is false, status_code must be present"

        synced_at = DateTime.utc_now()
        sync_status = "unattempted_error"
        {:error, ~m(sync_status error synced_at)}

      should_sync == false and csv_only == true ->
        sync_status = "queued_for_csv"
        {:other, ~m(sync_status)}

      true ->
        action_date = call["timestamp"]
        contact_type = "phone"
        canvass = ~m(action_date contact_type success status_code)
        {:ok, ~m(canvass add_tags add_answers)}
    end
  end

  def write_result(result, call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => result})
  end

  def fetch_aggregated_results(service_names, config) do
    zeros =
      Map.values(config)
      |> Enum.map(fn ~m(display_name) -> {display_name, 0} end)
      |> Enum.into(%{})

    Db.find(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status" => %{"$ne" => "ignored"}})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
    )
    |> Enum.reduce(%{}, fn ~m(full_on_screen_result), acc ->
      result = config[String.trim(full_on_screen_result)]["display_name"] || full_on_screen_result
      Map.update(acc, result, 1, &(&1 + 1))
    end)
    # |> Enum.into(zeros)
    |> Enum.map(fn tuple -> tuple end)
    |> Enum.sort_by(fn {_key, val} -> val end)
  end

  def get_success_count(service_names) do
    {:ok, n} =
      Db.count(
        "calls",
        Sync.Info.within_24_hours()
        |> Map.merge(%{"service_name" => %{"$in" => service_names}})
        |> Map.merge(%{"sync_status" => "finished"})
      )

    n
  end

  def get_error_count(service_names) do
    {:ok, n} =
      Db.count(
        "calls",
        Sync.Info.within_24_hours()
        |> Map.merge(%{"service_name" => %{"$in" => service_names}})
        |> Map.merge(%{
          "$or" => [
            %{"sync_status" => "attempted_error"},
            %{"sync_status" => "unattempted_error"}
          ]
        })
      )

    n
  end

  def upload_queued(slug, service_names, service_configuration) do
    Db.find(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status" => "queued_for_csv"})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
    )
    |> Sync.Csv.result_stream_to_csv(slug, service_configuration, & &1)
  end
end
