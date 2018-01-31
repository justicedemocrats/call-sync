defmodule Db do
  require Logger

  def insert_one(collection, documents) do
    Mongo.insert_one(:mongo, collection, documents, pool: DBConnection.Poolboy)
  end

  def update(collection, match, document) do
    Mongo.update_many!(
      :mongo,
      collection,
      match,
      %{"$set" => document},
      upsert: true,
      pool: DBConnection.Poolboy
    )
  end

  def find(collection, query, opts \\ []) do
    Mongo.find(:mongo, collection, query, Keyword.merge(opts, pool: DBConnection.Poolboy))
  end

  def count(collection, query) do
    Mongo.count(:mongo, collection, query, pool: DBConnection.Poolboy)
  end
end
