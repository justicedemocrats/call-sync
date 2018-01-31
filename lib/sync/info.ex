defmodule Sync.Info do
  import ShortMaps

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
    {:error, "failed to fetch_voter_id: phone not found"}
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
  def extract_id(~m(account)) do
    case String.split(account, "-") do
      [district, system, id] -> {:ok, ~m(district system id)}
      _ -> {:error, "failed to fetch voter id: bad account number format: #{account}"}
    end
  end
end
