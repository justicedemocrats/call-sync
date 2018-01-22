defmodule Van.Van.Api do
  use HTTPoison.Base
  import ShortMaps

  def application_name, do: Application.get_env(:call_sync, :application_name)

  # --------------- Process request ---------------
  defp process_url(url) do
    "https://api.securevan.com/v4/#{url}"
  end

  defp process_request_headers(hdrs) do
    hdrs
    |> Enum.into(
         Accept: "application/json",
         "Content-Type": "application/json"
       )
  end

  defp process_request_options(opts) do
    api_key = Keyword.get(opts, :api_key)

    opts
    |> Keyword.delete(:api_key)
    |> Keyword.put(:hackney, [basic_auth: {application_name(), "#{api_key}|0"}])
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
      key_name =
        Map.keys(docs)
        |> Enum.filter(& String.contains?(&1, "osdi:"))
        |> List.first()

      case docs[key_name] do
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
