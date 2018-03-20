defmodule Sync do
  import ShortMaps
  require Logger

  def sync_current_iteration do
    Logger.info("It's 5 after! Checking who to sync.")

    now = Timex.now("America/New_York")
    before = Timex.now() |> Timex.shift(minutes: -30)

    CallSync.AirtableCache.get_all().listings
    |> Enum.filter(fn {_slug, entry} -> entry["active"] == true end)
    |> Enum.filter(fn {_slug, config} -> is_queued(config, now, before) end)
    |> Enum.sort()
    |> Enum.map(fn {slug, _} ->
      Logger.info("Starting sync for #{slug}")
      Honeydew.async({:sync_candidate, [slug]}, :queue)
    end)
  end

  def sync_all do
    listings = CallSync.AirtableCache.get_all().listings

    listings
    |> Enum.filter(fn {_slug, entry} -> entry["active"] == true end)
    |> Enum.sort()
    # |> Enum.slice(2..200)
    |> Enum.map(fn {slug, _} ->
      Logger.info("Starting sync for #{slug}")
      Honeydew.async({:sync_candidate, [slug]}, :queue)
    end)
  end

  def is_queued(~m(sync_time reference_name), now, before) do
    {hours, _} = Integer.parse(sync_time)
    sync_date_time = Timex.now("America/New_York") |> Timex.set(hour: hours, minute: 0)

    cond do
      sync_date_time |> Timex.after?(now) ->
        Logger.info("Not syncing #{reference_name}, it's too early")
        false

      sync_date_time |> Timex.before?(before) ->
        Logger.info("Not syncing #{reference_name}, it's too late")
        false

      true ->
        true
    end
  end
end
