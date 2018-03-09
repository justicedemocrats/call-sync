defmodule Sync.AgentData do
  require Logger

  def login_management_url, do: Application.get_env(:call_sync, :login_management_url)

  def from(client_name, service_names) do
    agent_data =
      Db.distinct_callers(service_names)
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> Flow.from_enumerable(min_demand: 0, max_demand: 1)
      |> Flow.map(fn agent ->
        %{body: body} = HTTPotion.get(login_management_url() <> "/#{client_name}/#{agent}")
        attributes = Poison.decode!(body)
        Enum.map(~w(login email phone calling_from), &Map.get(attributes, &1))
      end)
      |> Enum.to_list()

    Enum.concat([~w(Login Email Phone From)], agent_data)
  end

  def upload_file(slug, rows) do
    time_comp = Timex.now() |> Timex.shift(days: -1) |> Timex.format!("{0M}-{0D}-{YYYY}")
    random_bits = Enum.map(0..8, fn _ -> Enum.random(0..9) end) |> Enum.join("")
    file_name = "#{slug}-agents-#{time_comp}-#{random_bits}.csv"

    path = Sync.Csv.write_to_temp_file(rows, file_name)
    Logger.info("Wrote to temp file #{path}.")
    file_url = Sync.Csv.upload_to_s3(path, file_name)
    Logger.info("Uploaded to #{file_url}")
    Sync.Csv.delete_temp_file(path)

    {file_url, length(rows) - 1}
  end
end
