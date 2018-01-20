defmodule Van.Api do
  use HTTPoison.Base
  import ShortMaps

  # --------------- Process request ---------------
  defp process_url(url) do
    "https://osdi.ngpvan.com/api/v1/#{url}"
  end

  defp process_request_headers(hdrs) do
    api_key = Keyword.get(hdrs, :api_key)

    hdrs
    |> Keyword.delete(:api_key)
    |> Enum.into(
         Accept: "application/json",
         "Content-Type": "application/json",
         "OSDI-API-Token": "#{api_key}|0"
       )
    |> IO.inspect()
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
         unfolder.(iter |> IO.inspect())
       end)
  end

  def enclose_unfolder(url, opts) do
    fn %{"total_pages" => tps, "page" => p, "_embedded" => docs} ->
      case docs["osdi:questions"] do
        [] ->
          if p == tps do
            nil
          else
            next_opts = Keyword.update(opts, :query, %{}, &Map.put(&1, "page", p + 1))
            %{body: body = %{"_embedded" => [first | rest]}} = get!(url, next_opts).body
            {first, Map.put(body, "_embedded", %{"osdi:questions" => rest})}
          end

        [first | rest] ->
          {
            first,
            %{"total_pages" => tps, "page" => p, "_embedded" => %{"osdi:questions" => rest}}
          }
      end
    end
  end
end
