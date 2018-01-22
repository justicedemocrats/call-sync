defmodule Van do
  def get_questions(api_key) do
    Van.Osdi.Api.stream("questions", api_key: api_key)
    |> Enum.to_list()
  end

  def get_tags(api_key) do
    Van.Osdi.Api.stream("tags", api_key: api_key)
    |> Enum.to_list()
  end

  def get_status_codes(api_key) do
    {:ok, %{body: body}} = Van.Van.Api.get("canvassResponses/resultCodes", [], api_key: api_key)
    body
  end
end
