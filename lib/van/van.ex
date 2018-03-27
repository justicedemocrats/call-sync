defmodule Van do
  def get_questions(api_key, mode \\ "van") do
    Van.Osdi.Api.stream("questions", api_key: api_key, mode: mode)
    |> Enum.to_list()
  end

  def get_tags(api_key, mode \\ "van") do
    Van.Osdi.Api.stream("tags", api_key: api_key, mode: mode)
    |> Enum.to_list()
  end

  def get_status_codes(api_key, mode \\ "van") do
    {:ok, %{body: body}} =
      Van.Van.Api.get("canvassResponses/resultCodes", [], api_key: api_key, mode: mode)

    body
  end

  def record_canvass(voter_id, canvass, api_key, mode \\ "van") do
    {:ok, %{body: body}} =
      Van.Osdi.Api.post(
        "people/#{voter_id}/record_canvass_helper",
        canvass,
        api_key: api_key,
        mode: mode,
        timeout: 1_000_000
      )

    {:ok, body}
  end
end
