defmodule Help do
  import ShortMaps

  def extract_id(osdi_doc) do
    osdi_doc
    |> Map.get("identifiers")
    |> List.first()
    |> String.split(":")
    |> List.last()
  end
end
