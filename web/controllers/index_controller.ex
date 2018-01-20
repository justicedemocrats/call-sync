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

  def question_lookup(conn, ~m(slug)) do
    resp =
      case AirtableCache.get_all()[slug] do
        ~m(api_key reference_name) ->
          questions = Van.get_questions(api_key)

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

          ~s[
            please paste pairs of question_id,response in QR 1 (and 2, 3, if desired)
            in the tag in Airtable corresponding to #{reference_name}

            for example, a correctly formatted row could be:
              1 - strong support -> #{Help.extract_id(first_question)},#{first_response["key"]}

            this would mean that strong support should be recorded as the first response
            to the first question

            if you add additional columns (which must be called QR 2, QR 3, ...)
            then you can trigger multiple responses for one result in livevox

            only QR 1 is required for every field

            here are the questions and their answers.\n\n
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
end
