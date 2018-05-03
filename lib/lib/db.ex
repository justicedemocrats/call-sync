defmodule Db do
  import ShortMaps
  require Logger

  def update(collection, match, operation) do
    Mongo.update_many!(
      :syncdb,
      collection,
      match,
      operation,
      upsert: true,
      pool: DBConnection.Poolboy,
      timeout: 100_000_000
    )
  end

  def find(collection, query, opts \\ []) do
    Mongo.find(
      :syncdb,
      collection,
      query,
      Keyword.merge(opts, pool: DBConnection.Poolboy, timeout: 1_000_000)
    )
  end

  def count(collection, query) do
    Mongo.count(:syncdb, collection, query, pool: DBConnection.Poolboy)
  end

  def distinct_callers(district) do
    query =
      CallSync.Info.within_24_hours()
      |> Map.merge(~m(district))

    Mongo.distinct!(:syncdb, "calls", "caller_login", query, pool: DBConnection.Poolboy)
  end
end
