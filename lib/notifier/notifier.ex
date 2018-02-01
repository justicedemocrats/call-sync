defmodule Notifier do
  import ShortMaps
  require Logger

  def zap_url, do: Application.get_env(:call_sync, :zapier_hook_url)

  def send(slug, data) do
    config = ~m(report_to) = CallSync.AirtableCache.get_all().listings[slug]
    day = Timex.now() |> Timex.shift(hours: -8) |> Timex.format!("{0M}-{0D}")

    subject = "Dialer Results for #{day}"
    text = format_text(config, data, day)

    Logger.info "Sending webhook to #{zap_url()} for report for #{slug} to #{report_to}"
    HTTPotion.post(zap_url(), body: Poison.encode!(~m(text report_to subject)))
  end

  def format_text(~m(reference_name), ~m(file_url aggregated_results), day) do
    results = Enum.map(aggregated_results, fn {key, count} ->
      ~s(\t\t#{String.pad_trailing(key, 10)}\t=>\t#{String.pad_leading(Integer.to_string(count), 10)})
    end)
    |> Enum.join("\n")

~s[
Hello! Hope you're having a good morning.

Your dialer results for #{reference_name} on #{day} have been processed and are ready for download at #{file_url}.

Note that this link will expire after 2 days for security reasons, so please download and save your results now.

Here's a breakdown of your results for the day:
#{results}

Any questions? Just reply to this email and it will go to Ben (programmer person at JD).
]
  end

  def format_text(~m(reference_name system), ~m(aggregated_results success_count error_count), day) do
    results = Enum.map(aggregated_results, fn {key, count} ->
      ~s(\t\t#{key}\t=>\t#{count})
    end)
    |> Enum.join("\n")

~s[
Hello! Hope you're having a good morning.

Your dialer results for #{reference_name} on #{day} have been processed and uploaded to #{system}.

Here's a breakdown of your results for the day:
#{results}

We successfully synced #{success_count}, and there were #{error_count} errors.

Any questions? Just reply to this email and it will go to Ben (programmer person at JD).
] |> IO.inspect()
  end
end
