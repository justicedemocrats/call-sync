defmodule CallSync.LoaderWorker do
  alias NimbleCSV.RFC4180, as: CSV
  require Logger
  import ShortMaps
  use Honeydew.Progress

  @report_interval 100
  @progress_interval 5
  @batch_size 10

  def upload_complete_hook, do: Application.get_env(:call_sync, :upload_complete_hook)
  def upload_failed_hook, do: Application.get_env(:call_sync, :upload_failed_hook)

  def load(~m(path)) do
    load(path)
  end

  def load(path) do
    try do
      ~m(listings configurations)a = CallSync.SyncConfig.get_all()

      processed =
        File.stream!(path)
        |> CSV.parse_stream()
        |> Stream.chunk_every(@batch_size)
        |> Stream.with_index()
        |> Stream.map(&update_progress/1)
        |> Stream.map(fn batch ->
          batch
          |> Enum.map(&line_to_map/1)
          |> Enum.reject(&should_skip/1)
          |> Enum.map(&resolve_term_code/1)
          # |> Enum.map(&add_service_info/1)
          |> Enum.map(fn call -> add_display_names(call, listings, configurations) end)
          |> Enum.map(&task_upsert/1)
          |> Enum.map(&Task.await/1)
        end)
        |> Stream.run()

      HTTPotion.post(upload_complete_hook(), body: Poison.encode!(~m(processed)))
      |> IO.inspect()

      CallSync.DataManager.add_service_names()
    rescue
      _ ->
        HTTPotion.post(
          upload_failed_hook(),
          body: Poison.encode!(%{"error" => "oh yeah, it errored"})
        )
        |> IO.inspect()
    end
  end

  # def skip(n) do
  #   fn {_, idx} ->
  #     if rem(idx, @report_interval) == 0 do
  #       Logger.info("Did #{idx * @batch_size}")
  #     end

  #     idx > n
  #   end
  # end

  def update_progress({line, idx}) do
    if rem(idx, @report_interval) == 0 do
      Logger.info("Did #{idx * @batch_size}")
    end

    if rem(idx, @progress_interval) == 0 do
      # progress(idx * @batch_size)
    end

    line
  end

  @doc ~S"""
  Transforms the line into a properly named map
      iex> CallSync.FileLoader.line_to_map([
          "101312525040", "nc05-van-18372073", "Allison", "Farrell", "9193879942",
          "02-05-2018 15:15:21", "02-05-2018 15:14:57", "02-05-2018 15:15:27", "",
          "Answering Machine (Hung Up)"
        ])
      %{"account_number" => "nc05-van-18372073", "caller_login" => "",
        "connect_time" => %DateTime{}, "district" => "nc05",
        "finish_time" => %DateTime{}, "first_name" => "Allison",
        "id" => "101312525040", "last_name" => "Farrell",
        "phone_dialed" => "9193879942", "result" => "Answering Machine (Hung Up)",
        "start_time" => %DateTime{}, "system_id" => "van",
        "timestamp" => %DateTime{}, "voter_id" => "18372073"}

  """
  def line_to_map(line) when is_list(line) do
    [
      id,
      account_number,
      first_name,
      last_name,
      phone_dialed,
      call_connect_time,
      call_start_time,
      call_finish_time,
      caller_login,
      result,
      campaign_id
    ] = line

    connect_time = nil_safe_time_parse(call_connect_time)
    start_time = nil_safe_time_parse(call_start_time)
    finish_time = nil_safe_time_parse(call_finish_time)
    timestamp = start_time
    lv_result = standardize_agent_term_code(result)

    case extract_voter_meta(account_number) do
      ~m(district system_id voter_id) ->
        ~m(id account_number first_name last_name phone_dialed connect_time
          start_time finish_time caller_login lv_result district system_id
          voter_id timestamp campaign_id)

      :skip ->
        :skip
    end
  end

  def extract_voter_meta(account_number) do
    case String.split(account_number, "-") do
      [district, system_id, voter_id] ->
        ~m(district system_id voter_id)

      ["TEST123" <> _] ->
        :skip

      ["123457"] ->
        :skip
    end
  end

  @doc ~S"""
    iex> CallSync.FileLoader.nil_safe_time_parse(nil)
    nil

    iex> CallSync.FileLoader.nil_safe_time_parse("02-05-2018 15:15:21")
    {:ok, %DateTime{}}
  """
  def nil_safe_time_parse(nil) do
    nil
  end

  def nil_safe_time_parse("") do
    nil
  end

  def nil_safe_time_parse(time_string) do
    {:ok, dt} = Timex.parse("#{time_string} -04:00", "{0D}-{0M}-{YYYY} {h24}:{m}:{s} {Z:}")
    dt
  end

  def should_skip(:skip), do: true
  def should_skip(_), do: false

  @doc ~S"""
    iex> CallSync.FileLoader.standardize_agent_term_code("Answering Machine (Hung Up)")
    "answering machine (hung up)"

    iex> CallSync.FileLoader.standardize_agent_term_code("Agent Cust 1 (167)")
    "agent cust 1"
  """
  def standardize_agent_term_code(code) do
    case String.downcase(code) do
      str = "agent" <> _ -> String.replace(str, ~r/[ ]+\(.*\)[ ]*/, "") |> String.trim()
      str -> str |> String.trim()
    end
  end

  @doc ~S"""
    iex> CallSync.FileLoader.resolve_term_code(%{"lv_result" => "answering machine (hung up)"})
    %{"lv_result" => "answering machine (hung up)", "full_on_screen_result" => "answering machine",
      "van_result" => "no answer", "dialed" => true}
  """
  def resolve_term_code(call = ~m(lv_result)) do
    extra_attributes = CallSync.TermCodeConfig.get_all()[lv_result]
    Map.merge(call, extra_attributes)
  end

  def add_service_info(call) do
    # TODO – figure out how to include service in report
    call
  end

  def add_display_names(call = ~m(full_on_screen_result district), listings, configurations) do
    client = infer_campaign(listings, district)
    fosr = String.trim(full_on_screen_result)

    case configurations[client][fosr] do
      nil ->
        IO.inspect(call)

      ~m(display_name) ->
        call
        |> Map.put("display_name", display_name)
        |> Map.put("client", client)
    end
  end

  def infer_campaign(campaigns, district) do
    campaigns
    |> Enum.filter(fn {_slug, ~m(district_abbreviation)} -> district_abbreviation == district end)
    |> Enum.map(fn {slug, _} -> slug end)
    |> List.first()
  end

  def task_upsert(call) do
    Task.async(fn -> upsert(call) end)
  end

  def upsert(call = ~m(id)) do
    Mongo.update_one(
      :syncdb,
      "calls",
      ~m(id),
      %{"$set" => call},
      upsert: true,
      pool: DBConnection.Poolboy
    )
  end
end
