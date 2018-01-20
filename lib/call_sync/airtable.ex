defmodule CallSync.AirtableCache do
  use Agent
  require Logger

  @interval 1_000_000

  def key, do: Application.get_env(:call_sync, :airtable_key)
  def base, do: Application.get_env(:call_sync, :airtable_base)
  def root_table, do: Application.get_env(:call_sync, :airtable_table_name)

  def start_link do
    Agent.start_link(
      fn ->
        update_all()
      end,
      name: __MODULE__
    )
  end

  def update() do
    Agent.update(__MODULE__, fn _current ->
      update_all()
    end)

    Logger.info("[call sync configuration]: updated at #{inspect(DateTime.utc_now())}")
  end

  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  def update_all do
    listings = root_table() |> fetch_all() |> process_integration_listings()

    configurations =
      Enum.map(integration_listings, fn ~m(reference_name slug) ->
        config = reference_name |> fetch_all() |> process_configuration()
        {slug, config}
      end)
      |> Enum.into(%{})

    ~m(listings configurations)a
  end

  defp fetch_all(for_table) do
    %{body: body} =
      HTTPotion.get("https://api.airtable.com/v0/#{base}/#{for_table}", headers: [
        Authorization: "Bearer #{key}"
      ])

    decoded = Poison.decode!(body)

    if Map.has_key?(decoded, "offset"),
      do: fetch_all(decoded["records"], decoded["offset"]),
      else: records
  end

  defp fetch_all(for_table, records, offset) do
    %{body: body} =
      HTTPotion.get(
        "https://api.airtable.com/v0/#{base}/#{for_table}",
        headers: [
          Authorization: "Bearer #{key}"
        ],
        query: [offset: offset]
      )

    decoded = Poison.decode!(body)
    new_records = decoded["records"]
    all_records = Enum.concat(records, new_records)

    if Map.has_key?(decoded, "offset"),
      do: fetch_all(all_records, decoded["offset"]),
      else: all_records
  end

  defp process_integration_listings(records) do
    records
    |> Enum.filter(fn ~m(fields) -> Map.has_key?(fields, "API Key") end)
    |> Enum.map(fn ~m(fields) ->
         {
           slugify(fields["Reference Name"]),
           %{
             "service_ids" => String.split(fields["Service Ids"]),
             "system" => fields["System"],
             "api_key" => fields["API Key"],
             "tag_ids" => fields["Tag Ids"],
             "sync_frequency" => fields["Sync Frequency"],
             "reference_name" => fields["Reference Name"]
           }
         }
       end)
    |> Enum.into(%{})
  end

  defp process_configuration(records) do
    records
    |> Enum.map(fn ->
         {
           fields["VAN Result"],
           fields
           |> Map.drop(["VAN Result"])
           |> Enum.map(fn {_qnum, val} -> val end)
           |> Enum.map(fn qr_pair -> String.split(qr_pair) |> Enum.map(&String.trim/1) end)
         }
       end)
    |> Enum.into(%{})
  end

  def slugify(reference_name) do
    reference_name
    |> String.downcase()
    |> String.replace(" ", "-")
  end
end
