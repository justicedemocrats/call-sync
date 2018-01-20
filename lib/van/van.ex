defmodule Van do
  def get_questions(api_key) do
    Van.Api.stream("questions", api_key: api_key)
    |> Enum.to_list()
  end

  def get_tags(api_key) do
    Van.Api.stream("tags", api_key: api_key)
    |> Enum.to_list()
  end
end
