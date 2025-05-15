defmodule LolApi.MatchesTest do
  use ExUnit.Case

  alias SharedUtils.Test.Support.HTTPSandbox

  describe "&get_matches/4" do
    test "returns a list of match IDs for the given puuid and time range" do
      url =
        "https://europe.api.riotgames.com/lol/match/v5/matches/by-puuid/0k88k9Y1ePbgXMDIKJygtw2SyueJL7w0uYLRqNN3IOobAqkj83RejSWd1kewlptB_OHf7Nk2eUbG0Q/ids?startTime=1630454400&endTime=1633046400&count=100"

      HTTPSandbox.set_get_responses([
        {url,
         fn ->
           {:ok,
            %Finch.Response{
              status: 200,
              headers: [],
              body:
                "[\"EUW1_7205646737\",\"EUW1_7205613245\",\"EUW1_7205576935\",\"EUW1_7205549702\",\"EUW1_7205508133\"]"
            }}
         end}
      ])

      expected = {
        :ok,
        [
          "EUW1_7205646737",
          "EUW1_7205613245",
          "EUW1_7205576935",
          "EUW1_7205549702",
          "EUW1_7205508133"
        ]
      }

      assert LolApi.get_matches(
               "europe",
               "0k88k9Y1ePbgXMDIKJygtw2SyueJL7w0uYLRqNN3IOobAqkj83RejSWd1kewlptB_OHf7Nk2eUbG0Q",
               1_630_454_400,
               1_633_046_400
             ) === expected
    end
  end
end
