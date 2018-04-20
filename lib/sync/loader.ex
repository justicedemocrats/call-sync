defmodule CallSync.Loader do
  import ShortMaps

  def load_candidate(slug) do
    ~m(service_names) = CallSync.SyncConfig.get_all().listings[slug]

    campaigns = campaigns_for_services(service_names) |> IO.inspect()

    Enum.flat_map(campaigns, fn context_data = ~m(campaign_id) ->
      get_all_finished_calls(
        [],
        %{"next" => "campaign/v6.0/campaigns/#{campaign_id}/finishedCalls"},
        context_data
      )
    end)
  end

  def get_all_finished_calls(acc, %{"next" => nil}, _) do
    acc
  end

  def get_all_finished_calls(acc, ~m(next), context_data) do
    offset =
      if String.contains?(next, "offset=") do
        next |> String.split("?") |> List.last() |> URI.decode_query() |> Map.get("offset")
      else
        0
      end

    url = String.split(next, "?") |> List.first()

    %{body: body = ~m(call)} =
      Livevox.Api.post(
        url,
        query: %{
          "count" => 1000,
          "offset" => offset
        },
        body: %{
          "windowStart" =>
            Timex.now("America/Los_Angeles")
            |> Timex.set(hour: 0)
            |> DateTime.to_unix(:milliseconds),
          "windowEnd" => Timex.now() |> DateTime.to_unix(:milliseconds)
        }
      )

    new_acc = Enum.map(call, &process_call(&1, context_data)) |> Enum.concat(acc)
    get_all_finished_calls(new_acc, body, context_data)
  end

  def process_call(call, context_data) do
    Map.merge(call, context_data)
  end

  def campaigns_for_services(service_names) do
    get_call_centers()
    |> get_service_ids_for_call_center_ids_matching_service_names(service_names)
    |> campaigns_for_service_ids()
  end

  def campaigns_for_service_ids(service_ids) do
    %{body: ~m(campaign)} =
      Livevox.Api.post(
        "campaign/campaigns/search",
        body: %{
          service: %{service: service_ids |> Enum.map(fn id -> ~m(id) end)},
          dateRange: %{
            from: Timex.now() |> Timex.shift(days: -5),
            to: Timex.now() |> Timex.shift(days: 5)
          }
        },
        query: %{offset: 0, count: 1000}
      )

    Enum.map(
      campaign,
      &%{
        "campaign_id" => &1["id"],
        "service_id" => &1["serviceId"],
        "campaign_name" => &1["name"],
        "service_name" => get_name_of_service_id(&1["serviceId"])
      }
    )
  end

  def get_call_centers() do
    %{body: ~m(callCenter)} =
      Livevox.Api.get("configuration/v6.0/callCenters", query: %{"count" => 1000, "offset" => 0})

    callCenter
    |> Enum.filter(&(&1["name"] != "Call Center"))
    |> Enum.map(& &1["callCenterId"])
  end

  def get_service_ids_for_call_center_ids_matching_service_names(call_center_ids, service_names) do
    call_center_ids
    |> Enum.flat_map(fn callCenterId ->
      %{body: ~m(service)} =
        Livevox.Api.get(
          "configuration/services",
          query: %{"callCenter" => callCenterId, "count" => 1000, "offset" => 0}
        )

      service
      |> Enum.map(&%{"name" => &1["name"], "id" => &1["serviceId"]})
      |> Enum.filter(&Enum.member?(service_names, &1["name"]))
      |> Enum.map(& &1["id"])
    end)
  end

  def get_name_of_service_id(service_id) do
    %{body: ~m(name)} = Livevox.Api.get("configuration/services/#{service_id}")
    name
  end
end
