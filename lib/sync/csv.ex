defmodule Sync.Csv do
  import ShortMaps
  import SweetXml
  require Logger
  alias NimbleCSV.RFC4180, as: CSV

  @print_interval 100

  def bucket_name, do: Application.get_env(:call_sync, :aws_bucket_name)

  def result_stream_to_csv(results_stream, slug, config) do
    Logger.info "Starting processing..."

    results =
      results_stream
      |> Stream.with_index()
      |> Flow.from_enumerable(min_demand: 50, max_demand: 100)
      |> Flow.filter(fn {call, idx} -> {should_sync(call, config), idx} end)
      |> Flow.map(fn {call, idx} ->
        if rem(idx, @print_interval) == 0 do
          Logger.info "Doing #{idx}"
        end
        convert_to_row(call, config)
      end)
      |> Enum.to_list()

    Logger.info "...done processing"

    ids = Enum.map(results, fn {id, _} -> id end)
    rows = [header_row() | Enum.map(results, fn {_, row} -> row end)]

    time_comp = Timex.now() |> Timex.shift(days: -1) |> Timex.format!("{0M}-{0D}-{YYYY}")
    random_bits = Enum.map(0..8, fn _ -> Enum.random(0..9) end) |> Enum.join("")
    file_name = "#{slug}-#{time_comp}-#{random_bits}.csv"

    path = write_to_temp_file(rows, file_name)
    Logger.info "Wrote to temp file #{path}."
    file_url = upload_to_s3(path, file_name)
    Logger.info "Uploaded to #{file_url}"
    delete_temp_file(path)

    mark_uploaded(ids, "#{file_url}")
    aggregated_results = aggregate(rows)

    ~m(file_url aggregated_results)
  end

  # --------------------- --------------------- ---------------------
  # ----------------------- Convert to a row ------------------------
  # --------------------- --------------------- ---------------------
  def header_row do
    [
      "Voter File",
      "Voter ID",
      "Voter First Name",
      "Voter Last Name",
      "Voter Phone",
      "Date Called",
      "Result",
      "Caller Login",
      "Caller Email"
    ]
  end

  def should_sync(~m(full_on_screen_result), config) do
    Map.has_key?(config, full_on_screen_result)
  end

  def convert_to_row(
        call = ~m(phone_dialed timestamp full_on_screen_result agent_name id),
        config
      ) do
    beginning =
      case Sync.Info.fetch_voter_id(call) do
        {:ok, ~m(system id first_name last_name)} -> [system, id, first_name, last_name]
        {:error, ~m(message first_name last_name)} -> ["Unknown", message, first_name, last_name]
      end

    row =
      Enum.concat(beginning, [
        phone_dialed,
        timestamp |> Timex.shift(hours: -8) |> Timex.format!("{0M}-{0D}-{YYYY}"),
        config[full_on_screen_result]["display_name"] || full_on_screen_result,
        agent_name,
        call["caller_email"]
      ])

    {id, row}
  end

  def mark_uploaded(ids, file_url) do
    sync_status = "finished"
    synced_at = DateTime.utc_now()
    receipt = file_url

    Db.update("calls", %{"id" => %{"$in" => ids}}, %{
      "$set" => ~m(sync_status synced_at receipt)
    })
  end

  def write_to_temp_file(rows, file_name) do
    File.mkdir_p("./files")
    path = "./files/#{file_name}"
    {:ok, out} = File.open(path, [:write])

    CSV.dump_to_stream(rows)
    |> Stream.map(fn row ->
      IO.binwrite(out, IO.iodata_to_binary(row))
    end)
    |> Stream.run()

    File.close(out)
    path
  end

  def upload_to_s3(path, file_name) do
    {:ok, %{body: body}} =
      path
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket_name(), file_name)
      |> ExAws.request()

    body |> xpath(~x"Location/text()")
  end

  def delete_temp_file(path) do
    File.rm(path)
  end

  def aggregate(rows) do
    Enum.reduce(rows, %{}, fn [_a, _b, _c, _d, _e, _f, g, _h, _i], acc ->
      Map.update(acc, g, 1, &(&1 + 1))
    end)
    |> Map.drop(~w(Result))
    |> Enum.map(fn tuple -> tuple end)
    |> Enum.sort_by(fn {key, _val} -> key end)
  end
end