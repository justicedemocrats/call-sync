defmodule Van.Osdi.Api do
  use HTTPoison.Base
  import ShortMaps

  # --------------- Process request ---------------
  defp process_url(url) do
    "https://osdi.ngpvan.com/api/v1/#{url}"
  end

  defp process_request_headers(hdrs) do
    api_key = Keyword.get(hdrs, :api_key)
    mode = Keyword.get(hdrs, :mode, "van")

    mode_int =
      case mode do
        "van" -> 0
        "myc" -> 1
      end

    hdrs
    |> Keyword.delete(:api_key)
    |> Enum.into(
      Accept: "application/json",
      "Content-Type": "application/json",
      "OSDI-API-Token": "#{api_key}|#{mode_int}"
    )
  end

  defp process_request_body(body) when is_map(body) do
    case Poison.encode(body) do
      {:ok, encoded} -> encoded
      {:error, _problem} -> body
    end
  end

  defp process_request_body(body) do
    body
  end

  # --------------- Process response ---------------
  defp process_response_body(text) do
    case Poison.decode(text) do
      {:ok, body} -> body
      _ -> text
    end
  end

  def stream(url, opts) do
    unfolder = enclose_unfolder(url, opts)

    ~m(body)a = get!(url, opts)

    body
    |> Stream.unfold(fn iter ->
      unfolder.(iter)
    end)
  end

  def enclose_unfolder(url, opts) do
    fn %{"total_pages" => tps, "page" => p, "_embedded" => docs} ->
      key_name =
        Map.keys(docs)
        |> Enum.filter(&String.contains?(&1, "osdi:"))
        |> List.first()

      case docs[key_name] do
        [] ->
          if p == tps or p > tps do
            nil
          else
            headers = opts
            params = %{"page" => p + 1}

            %{body: body = %{"_embedded" => %{^key_name => [first | rest]}}} =
              get!(url, headers, params: params)

            {first, Map.put(body, "_embedded", %{key_name => rest})}
          end

        [first | rest] ->
          {
            first,
            %{"total_pages" => tps, "page" => p, "_embedded" => Map.put(%{}, key_name, rest)}
          }
      end
    end
  end
end
