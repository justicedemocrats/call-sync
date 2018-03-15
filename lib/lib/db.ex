defmodule Db do
  require Logger

  def insert_one(collection, documents) do
    Mongo.insert_one(:mongo, collection, documents, pool: DBConnection.Poolboy)
  end

  def update(collection, match, operation) do
    Mongo.update_many!(
      :mongo,
      collection,
      match,
      operation,
      upsert: true,
      pool: DBConnection.Poolboy,
      timeout: 100_000_000
    )
  end

  def find(collection, query, opts \\ []) do
    Mongo.find(:mongo, collection, query, Keyword.merge(opts, pool: DBConnection.Poolboy))
  end

  def count(collection, query) do
    Mongo.count(:mongo, collection, query, pool: DBConnection.Poolboy)
  end

  def distinct_callers(service_names) when is_list(service_names) do
    query =
      Sync.Info.within_24_hours()
      |> Map.merge(%{"service_name" => %{"$in" => service_names}})

    Mongo.distinct!(:mongo, "calls", "agent_name", query, pool: DBConnection.Poolboy)
  end
end
