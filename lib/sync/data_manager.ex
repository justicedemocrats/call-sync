defmodule CallSync.DataManager do
  import ShortMaps
  require Logger

  def add_service_names do
    campaign_ids =
      Mongo.distinct!(
        :syncdb,
        "calls",
        "campaign_id",
        %{"service_name" => %{"$exists" => false}},
        pool: DBConnection.Poolboy
      )
      |> IO.inspect()

    campaign_ids
    |> Stream.map(&get_campaign_info/1)
    |> Stream.each(fn {campaign_id, data} ->
      Mongo.update_many!(
        :syncdb,
        "calls",
        %{"campaign_id" => campaign_id, "service_name" => %{"$exists" => false}},
        %{"$set" => data},
        pool: DBConnection.Poolboy
      )

      Logger.info("Added #{data["service_name"]}")
    end)
    |> Stream.run()
  end

  def get_campaign_info(campaign_id) do
    %{body: ~m(typeId serviceId)} = Livevox.Api.get("campaign/campaigns/#{campaign_id}")
    %{body: ~m(name)} = Livevox.Api.get("configuration/services/#{serviceId}")

    {campaign_id,
     %{"campaign_type_id" => typeId, "service_id" => serviceId, "service_name" => name}}
    |> IO.inspect()
  end
end
