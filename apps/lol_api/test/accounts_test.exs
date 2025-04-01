defmodule LolApi.AccountsTest do
  use ExUnit.Case

  describe "&get_account/3" do
    test "returns puuid for game_name and tag_line" do
      region = "americas"
      game_name = "asfdwrqe"
      tag_line = "krkr"
      url = "https://americas.api.riotgames.com/riot/account/v1/accounts/by-riot-id/asfdwrqe/krkr"

      HTTPSandbox.set_get_responses([
        {url,
         fn ->
           {:ok,
            %Finch.Response{
              status: 200,
              headers: [],
              body:
                "{\"puuid\":\"-Qg5ckGBhgiQyCS-mhcbSljPiYrfc6QTpVQtNLKrHGeCS4v3H2A53vw3JQTyw8SLOBRm-ZwsW9IOHQ\",\"gameName\":\"asfdwrqe\",\"tagLine\":\"krkr\"}"
            }}
         end}
      ])

      expected = {
        :ok,
        %{
          puuid: "-Qg5ckGBhgiQyCS-mhcbSljPiYrfc6QTpVQtNLKrHGeCS4v3H2A53vw3JQTyw8SLOBRm-ZwsW9IOHQ",
          game_name: game_name,
          tag_line: tag_line
        }
      }

      assert LolApi.get_account(region, game_name, tag_line) === expected
    end
  end
end
