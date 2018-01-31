defmodule Sync.Batch do
  import ShortMaps

  # Sync @batch_size results for the service in parallel, and record
  # If we're done (fetch_sync_bath_for returned no unsyced calls)
  #   -> send off the report
  # Otherwise
  #   -> recurse!
  def sync_batch(slug, service_ids, service_configuration, api_key) do
    batch_done =
      fetch_sync_batch_for(service_ids)
      |> Enum.map(fn call -> task_sync_call(call, service_configuration, api_key) end)
      |> Enum.map(fn t -> Task.await(t, limit: 30_000) end)

    if length(batch_done) == 0 do
      Notifier.report_service_results(slug)
    else
      sync_batch(slug, service_ids, service_configuration, api_key)
    end
  end

  # A call can be in several states –
  #   -> unsyced  – it will not have a sync property
  #   -> started  - the call has been fetched in a batch.
  #                 it could be stuck in this state if something goes wrong
  #   -> finished - we're done, and it either succeeded or failed with or without attempt
  def fetch_sync_batch_for(service_ids) do
    Db.find(
      "calls",
      %{"sync_status" => %{"$exists" => false}},
      sort: %{"timestamp" => 1},
      limit: 10
    )
    |> Enum.to_list()
  end

  # --------------------- --------------------- ---------------------
  # -------------------- Sync an individual call --------------------
  # --------------------- --------------------- ---------------------
  def task_sync_call(call, configuration, api_key) do
    Task.async(fn -> sync_call(call, configuration, api_key) end)
  end

  def sync_call(call, configuration, api_key) do
    send_out(call, configuration, api_key)
    |> write_result(call)
  end

  def send_out(call, configuration, api_key) do
    mark_started(call)

    case configure_body(call, configuration) do
      {:error, reason} ->
        %{success: false, attempted: false, reason: reason}

      {:ok, body} ->
        case Sync.Info.fetch_voter_id(call) do
          {:ok, ~m(district system id)} ->
            case Van.record_canvass(id, body, api_key) do
              osdi_result = ~m(identifiers) ->
                %{success: true, target_system: "van", receipt: Help.extract_id(osdi_result)}

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

  def configure_body(call, configuration) do
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
        ~m(canvass add_tags add_answers)
    end
  end

  def write_result(result, call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => %{sync_status: result}})
  end
end
