defmodule Notifier do
  import ShortMaps
  require Logger

  def zap_url, do: Application.get_env(:call_sync, :zapier_hook_url)
  def second_zap_url, do: Application.get_env(:call_sync, :second_zapier_hook_url)

  def send(slug, type, data) do
    config = ~m(report_to) = CallSync.SyncConfig.get_all().listings[slug]
    day = Timex.now() |> Timex.shift(days: -1) |> Timex.format!("{0M}-{0D}")

    subject = "Dialer Results for #{day}"

    ~m(aggregated_results) = data

    zero_results? = Enum.into(aggregated_results, %{}) |> Map.values() |> Enum.sum() == 0

    text =
      if zero_results? do
        zero_message(config)
      else
        format_text(config, type, data, day)
      end

    Logger.info("Sending webhook to #{zap_url()} for report for #{slug} to #{report_to}")
    HTTPotion.post(zap_url(), body: Poison.encode!(~m(text report_to subject)))
    HTTPotion.post(second_zap_url(), body: Poison.encode!(combine_results(data)))
  end

  def format_text(
        ~m(reference_name),
        "all csv",
        ~m(file_url aggregated_results total agent_count agent_file_url),
        day
      ) do
    results =
      Enum.map(aggregated_results, fn {key, count} ->
        ~s(\t\t#{String.pad_trailing(key, 10)}\t=>\t#{
          String.pad_leading(Integer.to_string(count), 10)
        })
      end)
      |> Enum.join("\n")

    ~s[
Hello! Hope you're having a good morning.

Your dialer results for #{reference_name} on #{day} have been processed and are ready for download at #{
      file_url
    }.

Note that this link will expire after 2 days for security reasons, so please download and save your results now.

Here's a breakdown of your #{total} total results for the day:
#{results}

You had #{agent_count} callers. You can download their contact information at #{agent_file_url}.

Any questions? Just reply to this email and it will go to Ben (programmer person at JD).
]
  end

  def format_text(
        ~m(reference_name system),
        "full",
        ~m(aggregated_results success_count error_count agent_count agent_file_url),
        day
      ) do
    results =
      Enum.map(aggregated_results, fn {key, count} ->
        ~s(\t\t#{key}\t=>\t#{count})
      end)
      |> Enum.join("\n")

    ~s[
Hello! Hope you're having a good morning.

Your dialer results for #{reference_name} on #{day} have been processed and uploaded to #{system}.

Here's a breakdown of your results for the day:
#{results}

We successfully synced #{success_count}, and there were #{error_count} errors.

You had #{agent_count} callers. You can download their contact information at #{agent_file_url}.

Any questions? Just reply to this email and it will go to Ben (programmer person at JD).
]
  end

  def format_text(
        ~m(reference_name system),
        "hybrid",
        ~m(aggregated_results success_count error_count file_url agent_count agent_file_url),
        day
      ) do
    results =
      Enum.map(aggregated_results, fn {key, count} ->
        ~s(\t\t#{key}\t=>\t#{count})
      end)
      |> Enum.join("\n")

    ~s[
Hello! Hope you're having a good morning.

Your dialer results for #{reference_name} on #{day} have been processed and uploaded to #{system}.

Here's a breakdown of your results for the day:
#{results}

We successfully synced #{success_count}, and there were #{error_count} errors.

To save you money, some of the results were not synced to your VAN. You can
download the unsynced results here: #{file_url}.

You had #{agent_count} callers. You can download their contact information at #{agent_file_url}.

Any questions? Just reply to this email and it will go to Ben (programmer person at JD).
]
  end

  def zero_message(~m(reference_name)) do
    ~s[
Hello! Hope you're having a good morning.

No calls were made for #{reference_name} yesterday, so this email is just to let
you know that our results reporting system are up and running :)

Any questions? Just reply to this email and it will go to Ben (programmer person at JD).
    ]
  end

  def combine_results(~m(aggregated_results csv_aggregated_results total csv_total)) do
    aggregated_results = Enum.into(aggregated_results, %{})
    csv_aggregated_results = Enum.into(csv_aggregated_results || [], %{})

    full_aggregation =
      Enum.concat(Map.keys(aggregated_results), Map.keys(csv_aggregated_results))
      |> Enum.map(fn value ->
        {value, (aggregated_results[value] || 0) + (csv_aggregated_results[value] || 0)}
      end)
      |> Enum.into(%{})

    full_total = total + csv_total
    Map.merge(full_aggregation, %{"total" => full_total})
  end

  def combine_results(~m(aggregated_results total)) do
    aggregated_results
    |> Enum.into(%{})
    |> Map.merge(~m(total))
  end
end
