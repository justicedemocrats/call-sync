defmodule Sync.Info do
  import ShortMaps

  def fetch_voter_id(phone_dialed) when is_binary(phone_dialed) do
    %{body: %{"findMatchingContactsDetails" => matches}} =
      Livevox.Api.post(
        "contact/v6.0/contacts/search",
        body: %{"filter" => %{"phone" => phone_dialed}},
        query: %{"count" => 100, "offset" => 0}
      )

    process_matches(matches)
  end

  def fetch_voter_id(~m(phone_dialed)) do
    %{body: %{"findMatchingContactsDetails" => matches}} =
      Livevox.Api.post(
        "contact/v6.0/contacts/search",
        body: %{"filter" => %{"phone" => phone_dialed}},
        query: %{"count" => 100, "offset" => 0}
      )

    process_matches(matches)
  end

  @doc ~S"""
  Filters and extracts the voter file id from 0, 1, or many livevox results,
  attempting helpful error messages

  ## Examples
    iex> Jobs.Sync.process_matches([%{"account" => "ny14-van-1"}])
    {:ok, %{"district" => "ny14", "system" => "van", "id" => "1"}}

    iex> Jobs.Sync.process_matches([%{"account" => "ny14-1"}])
    {:error, "failed to fetch voter id: bad account number format: ny14-1"}

    iex> Jobs.Sync.process_matches([%{"account" => "ny14-van-1"}, %{"account" => "ny14-1"}])
    {:ok, %{"district" => "ny14", "system" => "van", "id" => "1"}}
  """
  def process_matches([]) do
    message = "failed to fetch voter id: phone not found"
    first_name = ""
    last_name = ""
    {:error, ~m(message first_name last_name)}
  end

  def process_matches([one_match]) do
    extract_id(one_match)
  end

  def process_matches(many_matches) do
    extracted_matches =
      many_matches
      |> Enum.sort_by(& &1["modifyDate"], &>=/2)
      |> Enum.map(&extract_id/1)

    case Enum.filter(extracted_matches, &match?({:ok, _}, &1)) do
      [] -> List.first(extracted_matches)
      several_goods -> List.first(several_goods)
    end
  end

  @doc ~S"""
  Extracts the voter file id from the account number, attempting meaningful error
  messages

  ## Examples

    iex> Jobs.Sync.extract_id(%{"account" => "ny14-van-1"})
    {:ok, %{"district" => "ny14", "system" => "van", "id" => "1"}}

    iex> Jobs.Sync.extract_id(%{"account" => "ny14-1"})
    {:error, "failed to fetch voter id: bad account number format: ny14-1"}

  """
  def extract_id(~m(account person)) do
    first_name = person["firstName"]
    last_name = person["lastName"]

    case String.split(account, "-") do
      [district, system, id] ->
        {:ok, ~m(district system id first_name last_name)}

      _ ->
        message = "failed to fetch voter id: bad account number format: #{account}"
        {:error, ~m(message first_name last_name)}
    end
  end

  def within_24_hours do
    ago = Timex.shift(Timex.now(), hours: -144)
    %{"timestamp" => %{"$gt" => ago}}
  end

  def value_sum(list) when is_list(list) do
    list
    |> Enum.into(%{})
    |> value_sum()
  end

  def value_sum(map) when is_map(map) do
    Map.values(map) |> Enum.sum()
  end

  def value_sum(nil) do
    0
  end
end
