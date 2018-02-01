defmodule Sync.Batch do
  import ShortMaps

  @batch_size 10

  # Sync @batch_size results for the service in parallel, and record
  # If we're done (fetch_sync_bath_for returned no unsyced calls)
  #   -> send off the report
  # Otherwise
  #   -> recurse!
  def sync_batch(slug, service_names, service_configuration, api_key, mode) do
    batch_done =
      fetch_sync_batch_for(service_names)
      |> Enum.map(fn call -> task_sync_call(call, service_configuration, api_key, mode) end)
      |> Enum.map(fn t -> Task.await(t, 30_000) end)

    if length(batch_done) == 0 do
      [aggregated_results, success_count, error_count] =
        [
          Task.async(fn -> fetch_aggregated_results(service_names, service_configuration) end),
          Task.async(fn -> get_success_count(service_names) end),
          Task.async(fn -> get_error_count(service_names) end)
        ]
        |> Enum.map(&Task.await/1)

      Notifier.send(slug, ~m(aggregated_results success_count error_count))
    else
      sync_batch(slug, service_names, service_configuration, api_key, mode)
    end
  end

  # A call can be in several states –
  #   -> unsyced  – it will not have a sync property
  #   -> started  - the call has been fetched in a batch.
  #                 it could be stuck in this state if something goes wrong
  #   -> finished - we're done, and it either succeeded or failed with or without attempt
  def fetch_sync_batch_for(service_names) do
    Db.find(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status" => %{"$exists" => false}})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}}),
      sort: %{"timestamp" => 1},
      limit: @batch_size
    )
    |> Enum.to_list()
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

  def send_out(call, configuration, api_key, mode) do
    mark_started(call)

    case configure_body(call, configuration) do
      {:error, reason} ->
        %{success: false, attempted: false, reason: reason, ignored: true}

      {:ok, body} ->
        case Sync.Info.fetch_voter_id(call) do
          {:ok, ~m(district system id)} ->
            case Van.record_canvass(id, body, api_key, mode) do
              osdi_result = ~m(identifiers) ->
                %{success: true, target_system: "van", receipt: List.first(identifiers)}

              some_error ->
                %{success: false, attempted: true, reason: some_error}
            end

          {:error, error} ->
            %{sucess: false, attempted: false, reason: error}
        end
    end
  end

  def mark_started(call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => %{sync_status: %{"started" => true}}})
  end

  def configure_body(call = ~m(full_on_screen_result), config) do
    if Map.has_key?(config, full_on_screen_result) do
      do_configure_body(call, config)
    else
      {:error, "marked should not sync"}
    end
  end

  def do_configure_body(call, configuration) do
    key = call["full_on_screen_result"]
    result_map = configuration[key]

    status_code = Map.get(result_map, "result_code")
    add_tags = Map.get(result_map, "tags")
    success = Map.get(result_map, "success")

    add_answers =
      Map.get(result_map, "qr_pairs")
      |> Enum.map(fn {q, r} ->
        %{"question" => "https://osdi.ngpvan.com/api/v1/questions/#{q}", "responses" => [r]}
      end)

    cond do
      success != true and success != false ->
        {:error,
         "invalid configuration for #{key}: success is #{success}, and must be true or false"}

      success == false and (status_code == nil or status_code == "") ->
        {:error,
         "invalid configuration for #{key}: when success is false, status_code must be present"}

      true ->
        action_date = call["timestamp"]
        contact_type = "phone"
        canvass = ~m(action_date contact_type success status_code)
        {:ok, ~m(canvass add_tags add_answers)}
    end
  end

  def write_result(result, call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => %{sync_status: result}})
  end

  def fetch_aggregated_results(service_names, config) do
    Db.find(
      "calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status.ignored" => %{"$exists" => false}})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
    )
    |> Enum.reduce(%{}, fn (~m(full_on_screen_result), acc) ->
      result = config[full_on_screen_result]["display_name"] || full_on_screen_result
      Map.update(acc, result, 1, & &1 + 1)
    end)
    |> Enum.map(fn tuple -> tuple end)
    |> Enum.sort_by(fn {_key, val} -> val end)
  end

  def get_success_count(service_names) do
    {:ok, n} = Db.count("calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
      |> Map.merge(%{"sync_status.success" => true})
    )

    n
  end

  def get_error_count(service_names) do
    {:ok, n} = Db.count("calls",
      Sync.Info.within_24_hours()
      |> Map.merge(%{"sync_status.ignored" => %{"$exists" => false}})
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})
      |> Map.merge(%{"sync_status.success" => false})
    )

    n
  end
end
