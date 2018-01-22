defmodule CallSync.IndexController do
  import ShortMaps
  alias CallSync.{AirtableCache}
  use CallSync.Web, :controller

  def index(conn, _) do
    text conn, ~s(
      ENDPOINTS:
        /configure/:integration-name
    )
  end

  def configure_lookup(conn, ~m(slug)) do
    resp =
      case AirtableCache.get_all().listings[slug] do
        ~m(api_key reference_name) ->
          [questions, tags, status_codes] = Enum.map([
              Task.async(fn -> Van.get_questions(api_key) end),
              Task.async(fn -> Van.get_tags(api_key) end),
              Task.async(fn -> Van.get_status_codes(api_key) end)
            ], &Task.await/1)

          question_strings =
            questions
            |> Enum.map(fn question = ~m(description responses) ->
              response_strings =
                responses
                |> Enum.map(fn ~m(key title) -> ~s(
                  #{key} -> #{title}
                ) end)
                |> Enum.join("")

              ~s[
                #{Help.extract_id(question)} -> #{description}\n#{response_strings}
              ]
            end)
            |> Enum.join("\n\n")

          first_question = List.first(questions)
          first_response = List.first(first_question["responses"])

          tag_strings =
            tags
            |> Enum.map(fn tag = ~m(name description) ->
              ~s[
                #{name}(#{description}) -> #{Help.extract_id(tag)}
              ]
            end)

          status_codes_strings =
            status_codes
            |> Enum.map(fn ~m(resultCodeId name) ->
              ~s[
                #{name} -> #{resultCodeId}
              ]
            end)

          ~s[
            hello!

            in order to configure the sync for #{reference_name}, you'll need to
            add a canvass result code, some activist codes / tags, and/or some
            question and response pairs.

            to add a canvas result code, simply paste it into the box. you can only have one.

            to add some activist codes, paste them into the box.
            They should be comma separated. Please do not have trailing commas.

            to add some question response pairs, paste question,response in QR 1,
            and add a QR 2, 3, ... QR N if necessary.

            for example, a correctly formatted QR pair could be:
              1 - strong support -> #{Help.extract_id(first_question)},#{first_response["key"]}

            this would mean that strong support should be recorded as the first response
            to the first question

            i have included data below for you to copy and paste ids from.
            let me know if you have any questions

            #####################################################
            ################ CANVAS RESULT CODES ################
            #####################################################

            #{status_codes_strings}

            #####################################################
            ############### TAGS / ACTIVIST CODES ###############
            #####################################################

            #{tag_strings}

            #####################################################
            ############## QUESTIONS AND RESPONSES ##############
            #####################################################

            #{question_strings}
          ]

      _no_match ->
        options =
          AirtableCache.get_all()
          |> Enum.map(fn {slug, _} -> slug end)
          |> Enum.join(", ")

        ~s(that was an invalid integration reference name – try one of #{options})
      end

    text conn, resp
  end

  def tag_lookup(conn, ~m(slug)) do
    resp =
      case AirtableCache.get_all().listings[slug] do
        ~m(api_key reference_name) ->
          tags = Van.get_tags(api_key)
          Poison.encode!(tags)

        _no_match ->
          options =
            AirtableCache.get_all()
            |> Enum.map(fn {slug, _} -> slug end)
            |> Enum.join(", ")

          ~s(that was an invalid integration reference name – try one of #{options})
      end

    text conn, resp
  end

  def verify(conn, ~m(slug)) do
    resp =
      case AirtableCache.get_all().listings[slug] do
        ~m(api_key reference_name) ->
          configuration = AirtableCache.get_all().configurations[slug]
          questions = Van.get_questions(api_key)
          ~s(still working on it)

      _no_match ->
        options =
          AirtableCache.get_all()
          |> Enum.map(fn {slug, _} -> slug end)
          |> Enum.join(", ")

        ~s(that was an invalid integration reference name – try one of #{options})
      end

    text conn, resp
  end

  # def verify_result(result, configuration, questions) do
  #   case configuration[result] do
  #     [] -> {:error, "missing at least a QR1 for #{result}"}
  #     questions ->
  #       Enum.map()
  #   end
  # end
end
