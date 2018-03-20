defmodule CallSync.IndexController do
  import ShortMaps
  alias CallSync.{AirtableCache}
  use CallSync.Web, :controller

  def index(conn, _) do
    text(conn, ~s(
      ENDPOINTS:
        /status
        /configure/:integration-name
        /validate/:integration-name
    ))
  end

  def status(conn, _) do
    queued_text =
      get_queue()
      |> Enum.map(fn job ->
        ~s[
          #{job.task} -> #{job.status.status} (#{job.status.progress} processed)]
      end)
      |> Enum.join("\n")

    text(conn, ~s(
      QUEUD REPORTS:
        #{queued_text}
    ))
  end

  def configure_lookup(conn, ~m(slug)) do
    resp =
      case AirtableCache.get_all().listings[slug] do
        ~m(api_key reference_name system) ->
          [questions, tags, status_codes] =
            Enum.map(
              [
                Task.async(fn -> Van.get_questions(api_key, system) end),
                Task.async(fn -> Van.get_tags(api_key, system) end),
                Task.async(fn -> Van.get_status_codes(api_key, system) end)
              ],
              &Task.await/1
            )

          question_strings =
            questions
            |> Enum.map(fn question = ~m(description responses) ->
              response_strings =
                responses
                |> Enum.map(fn ~m(key title) -> ~s(
                  #{Help.extract_id(question)},#{key} -> #{title}
                ) end)
                |> Enum.join("")

              ~s[
                #{Help.extract_id(question)} -> #{description}\n#{response_strings}
              ]
            end)
            |> Enum.join("\n\n")

          first_question = List.first(questions)

          first_response =
            case first_question do
              ~m(responses) -> List.first(responses)
              _ -> nil
            end

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
            AirtableCache.get_all().listings
            |> Enum.map(fn {slug, _} -> slug end)
            |> Enum.join(", ")

          ~s(that was an invalid integration reference name – try one of #{options})
      end

    text(conn, resp)
  end

  def validate(conn, ~m(slug)) do
    resp =
      case AirtableCache.get_all().listings[slug] do
        ~m(api_key system) ->
          configuration = AirtableCache.get_all().configurations[slug]
          result = CallSync.Verification.verify(configuration, api_key, system)

          header_message =
            case result
                 |> Enum.flat_map(& &1)
                 |> Enum.filter(&match?({:error, _}, &1))
                 |> length() do
              0 -> "This sync is good to go!"
              _ -> "THIS SYNC HAS ERRORS!!!!"
            end

          row_results = Enum.zip(configuration, result)

          contents =
            Enum.map(row_results, fn {{full_on_screen, _}, validity} ->
              row_contents =
                Enum.map(validity, fn
                  {:ok, msg} -> ~s(
                #{msg}
              )
                  {:error, msg} -> ~s(
                !!!ERROR!!!: #{msg}
              )
                end)
                |> Enum.join("")

              ~s(
              #{full_on_screen} ---->>>>

              #{row_contents}
            )
            end)

          ~s(
            #{header_message}

            #{contents}
          )

        _no_match ->
          options =
            AirtableCache.get_all()
            |> Enum.map(fn {slug, _} -> slug end)
            |> Enum.join(", ")

          ~s(that was an invalid integration reference name – try one of #{options})
      end

    text(conn, resp)
  end

  def run(conn, ~m(slug)) do
    Honeydew.async(:sync_candidate, [slug], :queue)

    up_to = Timex.shift(Timex.now("America/New_York"), hours: -0) |> DateTime.to_iso8601()
    ago = Timex.shift(Timex.now("America/New_York"), hours: -24) |> DateTime.to_iso8601()

    text(conn, "Queued a sync of results from #{ago} to #{up_to}")
  end

  def get_queue do
    {{waiting, up_next}, _running} = Honeydew.state(:queue) |> List.first() |> Map.get(:private)

    running =
      Honeydew.status(:queue)
      |> Map.get(:workers)
      |> Map.values()
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(fn worker ->
        {task, status} = worker
        %{task: extract_task(task), status: extract_status(status)}
      end)

    Enum.concat(
      running,
      Enum.concat(waiting, up_next)
      |> Enum.map(fn job ->
        %{task: extract_task(job), status: %{status: "waiting", progress: 0}}
      end)
    )
  end

  def extract_task(%{task: {_, [candidate]}}) do
    candidate
  end

  def extract_status({status, progress}) do
    status = Atom.to_string(status)
    ~m(status progress)a
  end

  def extract_status(status) do
    progress = 0
    ~m(status progress)a
  end
end
