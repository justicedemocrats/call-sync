defmodule Sync.LoadOldResults do
  alias NimbleCSV.RFC4180, as: CSV
  import ShortMaps
  require Logger

  @report_interval 10

  def go(path) do
    path = "./old-results/#{path}"

    File.stream!(path)
    |> CSV.parse_stream()
    |> Stream.with_index()
    |> Flow.from_enumerable(min_demand: 500, max_demand: 1000)
    |> Flow.filter(&skip(&1, 590_000))
    |> Flow.map(&report/1)
    |> Flow.map(&to_map/1)
    |> Flow.filter(& &1)
    |> Flow.map(&to_archiveable_object/1)
    # |> Stream.each(&upsert/1)
    |> Flow.run()
  end

  def skip({_, idx}, greater) do
    idx > greater
  end

  def report({line, idx}) do
    if rem(idx, @report_interval) == 0 do
      Logger.info("Did #{idx}")
    end

    line
  end

  def to_map(line) do
    [
      account,
      voter_id,
      first_name,
      last_name,
      phone_dialed,
      lv_result,
      agent_term_code,
      custom_outcome,
      volunteer,
      spanish,
      call_duration,
      list,
      agent_id,
      call_date,
      candidate
    ] = line

    case service_name_of(candidate) do
      false ->
        false

      service_name ->
        timestamp = Timex.parse!(call_date, "{M}/{D}/{YY}")
        timestamp = Timex.to_unix(timestamp)
        agent_login_id = agent_id
        agent_name = agent_id

        ~m(list account voter_id first_name last_name phone_dialed lv_result agent_term_code
           volunteer spanish call_duration agent_id timestamp service_name agent_id agent_login_id agent_name)
    end
  end

  def to_archiveable_object(call = ~m(lv_result)) do
    endpoint =
      if lv_result |> String.downcase() |> String.contains?("agent") do
        "http://localhost:4000/process-agent"
      else
        "http://localhost:4000/process-call"
      end

    try do
      %{body: archiveable} =
        case Poison.encode(call) do
          {:ok, encoded} ->
            HTTPotion.post(endpoint, [body: encoded] ++ [headers: headers()])

          _ ->
            {:ok, "[false]"}
        end
    rescue
      _ ->
        IO.inspect(call)
        {:ok, "[false]"}
    end

    # Poison.decode!(archiveable)
  end

  def upsert(call) do
    call
  end

  def headers,
    do: [
      Accept: "application/json",
      "Content-Type": "application/json"
    ]

  def service_name_of("Bush"), do: "MO-01: Callers"
  def service_name_of("Swearengin"), do: "WV-SN: Callers"
  def service_name_of("Smith"), do: "WA-09: Callers"
  def service_name_of("Ryerse"), do: "AR-03: Callers"
  def service_name_of("Ocasio"), do: "NY-14: Callers"
  def service_name_of("Client - Thurston"), do: false
  def service_name_of("Client - Budd"), do: false
  def service_name_of("Hartson"), do: "CA-SN: Callers"
  def service_name_of("Client - Beto"), do: "Beto for Senate Callers"
  def service_name_of("Crowe"), do: "TX-21: Callers"
  def service_name_of("Mustafa"), do: "IL-05: Callers"
  def service_name_of("Gasque"), do: "WA-03: Callers"
  def service_name_of("King"), do: "PA-11: Callers"
  def service_name_of("Calderon"), do: "CA-04: Callers"
  def service_name_of("Thompson"), do: "KS-04: Callers"
  def service_name_of("Canon"), do: "IN-09: Callers"
  def service_name_of("Matiella"), do: "AZ-02: Callers"
  def service_name_of("Beals"), do: "NY-19: Callers"
  def service_name_of("Clark"), do: "IL-03: Callers"
  def service_name_of("Benac"), do: "MI-06: Callers"
  def service_name_of("Trevino"), do: "TX-23: Callers"
  def service_name_of("Gill"), do: "IL-13: Callers"
  def service_name_of("Newman"), do: "IL-03: Callers"
  def service_name_of("Caforio"), do: "CA-25: Callers"
  def service_name_of("Vilela"), do: "NV-04: Callers"
  def service_name_of("Lopez"), do: "NM-01: Callers"
  def service_name_of("Nelson"), do: "NM-01: Callers"
  def service_name_of("Edwards"), do: "PA-07: Callers"
  def service_name_of("Client - Mercuri"), do: false
  def service_name_of("Bell"), do: "TX-14: Callers"
  def service_name_of("Moser"), do: "TX-07: Callers"
  def service_name_of("Spaulding"), do: "CO-05: Callers"

  def service_name_of("MISSING"), do: false
end
