defmodule Archive do
  require Logger
  import ShortMaps

  @archive_shift [days: -0]
  @print_interval 100
  @chunk_size 100

  @collection "calls"

  def go do
    timestamp = %{"$lt" => Timex.now() |> Timex.shift(@archive_shift)}

    {:ok, count} =
      Mongo.count(:productiondb, @collection, ~m(timestamp), pool: DBConnection.Poolboy)

    Logger.info("Have #{count} to archive")

    Mongo.find(:productiondb, @collection, ~m(timestamp), pool: DBConnection.Poolboy)
    |> Stream.chunk_every(@chunk_size)
    |> Stream.with_index()
    |> Stream.each(&archive/1)
    |> Stream.run()
  end

  def archive({calls_chunk, idx}) do
    ids = Enum.map(calls_chunk, & &1["_id"])

    Mongo.insert_many(:archivedb, @collection, calls_chunk, pool: DBConnection.Poolboy)

    {:ok, _} =
      Mongo.delete_many(
        :productiondb,
        @collection,
        %{"_id" => %{"$in" => ids}},
        pool: DBConnection.Poolboy
      )

    if rem(idx, @print_interval) == 0 do
      Logger.info("Done #{idx * @chunk_size}")
    end
  end
end
