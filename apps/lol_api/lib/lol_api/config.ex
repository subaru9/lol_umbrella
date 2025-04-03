defmodule LolApi.Config do
  def api_key!(), do: Application.fetch_env!(:lol_api, :api_key)
end
