defmodule Help do
  import ShortMaps

  def extract_id(~m(identifiers)) do
    identifiers
    |> List.first()
    |> String.split(":")
    |> List.last()
  end

  def extract_id(_) do
    "none"
  end
end
