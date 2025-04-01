defmodule LolApi.LeagueEntriesTest do
  use ExUnit.Case
  doctest LolApi

  describe "&get_league_entries/4" do
    test "returns data with summoner_id per entry" do
      page1 =
        "https://euw1.api.riotgames.com/lol/league/v4/entries/RANKED_SOLO_5x5/DIAMOND/I?page=1"

      page2 =
        "https://euw1.api.riotgames.com/lol/league/v4/entries/RANKED_SOLO_5x5/DIAMOND/I?page=2"

      HTTPSandbox.set_get_responses([
        {page1,
         fn ->
           {:ok,
            %Finch.Response{
              status: 200,
              headers: [],
              body:
                "[{\"leagueId\":\"67f71fa1-fa23-4bb8-a093-2215e1c05686\",\"queueType\":\"RANKED_SOLO_5x5\",\"tier\":\"DIAMOND\",\"rank\":\"I\",\"summonerId\":\"2RLX7vrqAs_VB43LCljfBYL6L9w591Qu8SBHvQReUh8rOgHU\",\"leaguePoints\":4,\"wins\":171,\"losses\":177,\"veteran\":false,\"inactive\":false,\"freshBlood\":true,\"hotStreak\":true}]"
            }}
         end}
      ])

      HTTPSandbox.set_get_responses([
        {page2,
         fn ->
           {:ok,
            %Finch.Response{
              status: 200,
              headers: [],
              body: "[]"
            }}
         end}
      ])

      expected = {
        :ok,
        [
          %{
            "freshBlood" => true,
            "hotStreak" => true,
            "inactive" => false,
            "leagueId" => "67f71fa1-fa23-4bb8-a093-2215e1c05686",
            "leaguePoints" => 4,
            "losses" => 177,
            "queueType" => "RANKED_SOLO_5x5",
            "rank" => "I",
            "summonerId" => "2RLX7vrqAs_VB43LCljfBYL6L9w591Qu8SBHvQReUh8rOgHU",
            "tier" => "DIAMOND",
            "veteran" => false,
            "wins" => 171
          }
        ]
      }

      assert LolApi.get_league_entries("euw1", "RANKED_SOLO_5x5", "DIAMOND", "I") === expected
    end

    test "invalid token" do
      url =
        "https://euw1.api.riotgames.com/lol/league/v4/entries/RANKED_SOLO_5x5/DIAMOND/I?page=1"

      HTTPSandbox.set_get_responses([
        {url,
         fn ->
           {:ok,
            %Finch.Response{
              status: 403,
              headers: [],
              body: "{\"status\":{\"message\":\"Forbidden\",\"status_code\":403}}"
            }}
         end}
      ])

      expected = {:error, ErrorMessage.forbidden("Forbidden", %{endpoint: url})}
      assert LolApi.get_league_entries("euw1", "RANKED_SOLO_5x5", "DIAMOND", "I") === expected
    end
  end
end
