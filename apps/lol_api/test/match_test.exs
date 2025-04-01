defmodule LolApi.MatchTest do
  use ExUnit.Case

  describe "&get_match/2" do
    test "returns core match statistics for a valid match_id" do
      region = "europe"
      match_id = "EUW1_7175686677"
      url = "https://europe.api.riotgames.com/lol/match/v5/matches/#{match_id}"

      HTTPSandbox.set_get_responses([
        {url,
         fn ->
           {:ok,
            %Finch.Response{
              status: 200,
              headers: [],
              body:
                "{\"metadata\":{\"matchId\":\"EUW1_7175686677\",\"participants\":[\"player1\",\"player2\"]},\"info\":{\"gameId\":7175686677,\"gameMode\":\"CLASSIC\",\"gameDuration\":110,\"participants\":[{\"championId\":39,\"teamId\":100,\"kills\":10,\"deaths\":2,\"assists\":5},{\"championId\":157,\"teamId\":200,\"kills\":7,\"deaths\":8,\"assists\":3}]}}"
            }}
         end}
      ])

      expected = {
        :ok,
        %{
          "metadata" => %{
            "matchId" => "EUW1_7175686677",
            "participants" => ["player1", "player2"]
          },
          "info" => %{
            "gameId" => 7_175_686_677,
            "gameMode" => "CLASSIC",
            "gameDuration" => 110,
            "participants" => [
              %{
                "championId" => 39,
                "teamId" => 100,
                "kills" => 10,
                "deaths" => 2,
                "assists" => 5
              },
              %{
                "championId" => 157,
                "teamId" => 200,
                "kills" => 7,
                "deaths" => 8,
                "assists" => 3
              }
            ]
          }
        }
      }

      assert LolApi.get_match(region, match_id) === expected
    end
  end
end
