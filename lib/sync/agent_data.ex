defmodule CallSync.AgentData do
  require Logger

  @max_attempts 5
  @sleep_period 2_000

  def login_management_url, do: Application.get_env(:call_sync, :login_management_url)

  def from(district) do
    agent_data =
      Db.distinct_callers(district)
      |> Stream.filter(&(&1 != nil and &1 != ""))
      |> Stream.map(fn agent ->
        do_get_agent_data(agent, 1)
      end)
      |> Enum.to_list()

    Enum.concat([~w(Login Email Phone From)], agent_data)
  end

  def do_get_agent_data(agent, attempt) do
    try do
      %{body: body} = HTTPotion.get(login_management_url() <> "/infer-client/#{agent}")
      attributes = Poison.decode!(body)
      Enum.map(~w(login email phone calling_from), &Map.get(attributes, &1))
    rescue
      _e ->
        if attempt < @max_attempts do
          Logger.info("Retrying – attempt #{attempt + 1}")
          :timer.sleep(@sleep_period)
          do_get_agent_data(agent, attempt + 1)
        else
          ["", "", "", ""]
        end
    end
  end

  def upload_file(slug, rows) do
    time_comp = Timex.now() |> Timex.shift(days: -1) |> Timex.format!("{0M}-{0D}-{YYYY}")
    random_bits = Enum.map(0..8, fn _ -> Enum.random(0..9) end) |> Enum.join("")
    file_name = "#{slug}-agents-#{time_comp}-#{random_bits}.csv"

    path = CallSync.Csv.write_to_temp_file(rows, file_name)
    Logger.info("Wrote to temp file #{path}.")
    file_url = CallSync.Csv.upload_to_s3(path, file_name)
    Logger.info("Uploaded to #{file_url}")
    CallSync.Csv.delete_temp_file(path)

    {file_url, length(rows) - 1}
  end
end
