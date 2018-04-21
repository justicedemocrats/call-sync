defmodule Archive do
  require Logger
  import ShortMaps

  @archive_shift [days: -5]
  @print_interval 100
  @chunk_size 100

  def go(collection) do
    _conn =
      case Mongo.start_link(
             name: :backupdb,
             database: "livevox-archives",
             username: Application.get_env(:call_sync, :backupdb_username),
             password: Application.get_env(:call_sync, :backupdb_password),
             seeds: Application.get_env(:call_sync, :backupdb_seeds),
             port: Application.get_env(:call_sync, :backupdb_port)
           ) do
        {:ok, conn} -> conn
        {:error, {:already_started, conn}} -> conn
      end

    timestamp = %{"$lt" => Timex.now() |> Timex.shift(@archive_shift)}

    {:ok, count} = Db.count(collection, ~m(timestamp))

    Logger.info("Have #{count} to archive")

    Db.find(collection, ~m(timestamp))
    |> Stream.chunk_every(@chunk_size)
    |> Stream.with_index()
    |> Stream.each(&archive(&1, collection))
    |> Stream.run()
  end

  def archive({calls_chunk, idx}, collection) do
    ids = Enum.map(calls_chunk, & &1["_id"])

    Mongo.insert_many(:backupdb, collection, calls_chunk)

    query = %{"_id" => %{"$in" => ids}}

    {:ok, _} =
      Mongo.delete_many(
        :mongo,
        collection,
        %{"_id" => %{"$in" => ids}},
        pool: DBConnection.Poolboy
      )

    if rem(idx, @print_interval) == 0 do
      Logger.info("Done #{idx * @chunk_size}")
    end
  end
end
