defmodule Sync.Bulk do
  import ShortMaps

  def sync_bulk(slug, service_ids, service_configuration) do
    rows =
      stream_all_unsynced(service_ids)
      |> Flow.from_enumerable()
      |> Flow.map(fn call -> convert_to_row(call, service_configuration) end)
      |> Enum.to_list()
  end

  # A call can be in several states –
  #   -> unsyced  – it will not have a sync property
  #   -> started  - the call has been fetched in a batch.
  #                 it could be stuck in this state if something goes wrong
  #   -> finished - we're done, and it either succeeded or failed with or without attempt
  def stream_all_unsynced(service_ids) do
    Db.find("calls", %{"sync_status" => %{"$exists" => false}}, sort: %{"timestamp" => 1})
  end

  # --------------------- --------------------- ---------------------
  # ----------------------- Convert to a row ------------------------
  # --------------------- --------------------- ---------------------
  def convert_to_row(call, service_configuration) do
    case Sync.Info.fetch_voter_id(call) do
      {:ok, ~m(district system id)} ->
        [id]

      {:error, error} ->
        nil
    end
  end

  def write_result(result, call) do
    ~m(id) = call
    Db.update("calls", ~m(id), %{"$set" => %{sync_status: result}})
  end
end
