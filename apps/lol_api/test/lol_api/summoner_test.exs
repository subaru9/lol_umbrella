defmodule LolApi.SummonerTest do
  use ExUnit.Case

  alias SharedUtils.Test.Support.HTTPSandbox

  describe "&get_summoner/2" do
    test "returns summoner details for a valid summoner_id" do
      url =
        "https://euw1.api.riotgames.com/lol/summoner/v4/summoners/2RLX7vrqAs_VB43LCljfBYL6L9w591Qu8SBHvQReUh8rOgHU"

      HTTPSandbox.set_get_responses([
        {url,
         fn ->
           {:ok,
            %Finch.Response{
              status: 200,
              headers: [],
              body:
                "{\"id\":\"2RLX7vrqAs_VB43LCljfBYL6L9w591Qu8SBHvQReUh8rOgHU\",\"accountId\":\"fGuNYI3heOGiHLRb7KV9eUVZ6vYkxa7uHtpOguRtlIemXGU\",\"puuid\":\"BFT9hQFvdN8PBCc4RqBRwWMkjs2G7RFaKzAEPzRC3yHgF8FVFhriddny_TnFQU8BZsSj7PnFMGy1-w\",\"profileIconId\":1456,\"revisionDate\":1732747632762,\"summonerLevel\":661}"
            }}
         end}
      ])

      expected = {
        :ok,
        %{
          id: "2RLX7vrqAs_VB43LCljfBYL6L9w591Qu8SBHvQReUh8rOgHU",
          account_id: "fGuNYI3heOGiHLRb7KV9eUVZ6vYkxa7uHtpOguRtlIemXGU",
          puuid: "BFT9hQFvdN8PBCc4RqBRwWMkjs2G7RFaKzAEPzRC3yHgF8FVFhriddny_TnFQU8BZsSj7PnFMGy1-w",
          profile_icon_id: 1456,
          revision_date: 1_732_747_632_762,
          summoner_level: 661
        }
      }

      assert LolApi.get_summoner("euw1", "2RLX7vrqAs_VB43LCljfBYL6L9w591Qu8SBHvQReUh8rOgHU") ===
               expected
    end
  end
end
