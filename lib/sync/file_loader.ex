defmodule CallSync.FileLoader do
  alias NimbleCSV.RFC4180, as: CSV
  require Logger
  import ShortMaps

  @report_interval 1000

  def load(path) do
    File.stream!(path)
    |> CSV.parse_stream()
    |> Stream.with_index()
    |> Stream.filter(skip(46000))
    |> Flow.from_enumerable(min_demand: 5, max_demand: 10, stages: 20)
    |> Flow.map(&update_progress/1)
    |> Flow.map(&line_to_map/1)
    |> Flow.reject(&should_skip/1)
    |> Flow.map(&resolve_term_code/1)
    # |> Stream.map(&add_service_info/1)
    |> Flow.map(&add_display_names/1)
    |> Flow.map(&upsert/1)
    |> Flow.run()
  end

  def skip(n) do
    fn {_, idx} ->
      if rem(idx, @report_interval) == 0 do
        Logger.info("Did #{idx}")
      end

      idx > n
    end
  end

  def update_progress({line, idx}) do
    if rem(idx, @report_interval) == 0 do
      Logger.info("Did #{idx}")
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

  def add_display_names(call = ~m(full_on_screen_result district)) do
    client = infer_campaign(CallSync.SyncConfig.get_all().listings, district)
    fosr = String.trim(full_on_screen_result)

    case CallSync.SyncConfig.get_all().configurations[client][fosr] do
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
