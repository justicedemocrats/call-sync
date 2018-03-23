defmodule CallSync.AirtableCache do
  use Agent
  require Logger
  import ShortMaps

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
    Agent.update(
      __MODULE__,
      fn _current ->
        update_all()
      end,
      20_000
    )

    Logger.info("[call sync configuration]: updated at #{inspect(DateTime.utc_now())}")
  end

  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  def update_all do
    listings = root_table() |> fetch_all() |> process_integration_listings()

    configurations =
      Enum.map(listings, fn {slug, ~m(reference_name)} ->
        config = reference_name |> fetch_all() |> process_configuration()
        {slug, config}
      end)
      |> Enum.into(%{})

    ~m(listings configurations)a
  end

  defp fetch_all(for_table) do
    %{body: body} =
      HTTPotion.get(
        "https://api.airtable.com/v0/#{base()}/#{URI.encode(for_table)}",
        headers: [
          Authorization: "Bearer #{key()}"
        ],
        timeout: :infinity
      )

    decoded = Poison.decode!(body)

    if Map.has_key?(decoded, "offset"),
      do: fetch_all(for_table, decoded["records"], decoded["offset"]),
      else: decoded["records"]
  end

  defp fetch_all(for_table, records, offset) do
    %{body: body} =
      HTTPotion.get(
        "https://api.airtable.com/v0/#{base()}/#{URI.encode(for_table)}",
        headers: [
          Authorization: "Bearer #{key()}"
        ],
        query: [offset: offset],
        timeout: :infinity
      )

    decoded = Poison.decode!(body)
    new_records = decoded["records"]
    all_records = Enum.concat(records, new_records)

    if Map.has_key?(decoded, "offset"),
      do: fetch_all(for_table, all_records, decoded["offset"]),
      else: all_records
  end

  defp process_integration_listings(records) do
    records
    |> Enum.filter(fn ~m(fields) -> Map.has_key?(fields, "Service Names") end)
    |> Enum.map(fn ~m(fields) ->
      {
        slugify(fields["Reference Name"]),
        %{
          "service_names" =>
            String.split(fields["Service Names"], ",") |> Enum.map(&String.trim(&1)),
          "system" => fields["System"],
          "api_key" => fields["API Key"],
          "tag_ids" => fields["Tag Ids"],
          "active" => fields["Active"],
          "reference_name" => fields["Reference Name"],
          "strategy" => fields["Strategy"],
          "report_to" => fields["Send Report To"],
          "sync_time" => fields["Sync Time (EST)"],,
        }
      }
    end)
    |> Enum.into(%{})
  end

  defp process_configuration(records) do
    records
    |> Enum.map(fn ~m(fields) ->
      success = fields["Success"] == true
      result_code = fields["Canvass Result Code"]
      should_sync = fields["Sync to System"]
      csv_only = fields["Include in CSV"]
      display_name = fields["Display Name"]

      tags =
        case fields["Tags"] do
          nil -> []
          "" -> []
          string -> String.split(string, ",")
        end

      qrs_left =
        Map.drop(fields, [
          "Full On Screen Result",
          "Tags",
          "Success",
          "Canvass Result Code",
          "Used?",
          "Sync to System",
          "Include in CSV",
          "Display Name"
        ])

      qr_pairs =
        qrs_left
        |> Enum.map(fn {_qnum, val} -> val end)
        |> Enum.map(fn qr_pair ->
          [q, r] = String.split(qr_pair, ",") |> Enum.map(&String.trim/1)
          {q, r}
        end)

      {String.downcase(fields["Full On Screen Result"]),
       ~m(success result_code tags qr_pairs display_name should_sync csv_only)}
    end)
    |> Enum.filter(fn {_, ~m(should_sync csv_only)} -> should_sync == true or csv_only == true end)
    |> Enum.into(%{})
  end

  def slugify(reference_name) do
    reference_name
    |> String.downcase()
    |> String.replace(" ", "-")
    |> String.replace("''", "")
  end
end
