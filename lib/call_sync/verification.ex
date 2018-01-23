defmodule CallSync.Verification do
  import ShortMaps

  def verify(configuration, api_key) do
    [questions, tags, status_codes] =
      Enum.map(
        [
          Task.async(fn -> Van.get_questions(api_key) end),
          Task.async(fn -> Van.get_tags(api_key) end),
          Task.async(fn -> Van.get_status_codes(api_key) end)
        ],
        &Task.await/1
      )

    data = ~m(questions tags status_codes)

    configuration
    |> Flow.from_enumerable()
    |> Flow.map(fn {result, components} ->
         Flow.from_enumerable(components)
         |> Flow.flat_map(fn {type, value} ->
              verified = verify_component(type, value, data)

              if is_list(verified) do
                verified
              else
                [verified]
              end
            end)
         |> Enum.to_list()
       end)
  end

  def verify_component("success", val, _) do
    if is_boolean(val) do
      {:ok, "Success: #{val}"}
    else
      {:error, "#{val} is not true or false"}
    end
  end

  def verify_component("result_code", val, ~m(status_codes)) do
    match =
      status_codes
      |> Enum.filter(&(&1["resultCodeId"] == val))
      |> List.first()

    case match do
      nil -> {:error, "Could not find a result code with a value of #{val}"}
      ~m(name) -> {:ok, "Result code: #{name}"}
    end
  end

  def verify_component("tags", vals, ~m(tags)) do
    Enum.map(vals, fn id ->
      match =
        Enum.filter(tags, fn t ->
          Help.extract_id(t) == id
        end)
        |> List.first()

      case match do
        ~m(name) -> {:ok, "Add tag: #{name}"}
        nil -> {:error, "Could not find a tag / activist code with id: #{id}"}
      end
    end)
  end

  def verify_component("qr_pairs", ~m(questions)) do
    Enum.map(questions, fn {q, r} ->
      q_match = Enum.filter(questions, fn question -> Help.extract_id(question) == q end)

      case q_match do
        nil ->
          {:error, "Could not find question with id: #{q}"}

        ~m(description responses) ->
          r_match =
            Enum.filter(responses, fn ~m(key) ->
              key == r
            end)

          case r_match do
            ~m(title) ->
              {:ok, ~s(Response: answer #{title} to #{description})}

            nil ->
              {:error, "Question #{description} (#{q}) does not have a response with id #{r}"}
          end
      end
    end)
  end
end
