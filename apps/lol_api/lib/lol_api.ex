defmodule LolApi do
  @moduledoc """
  Provides access to Riot Games API
  """

  alias LolApi.Embeds
  alias LolApi.Base

  @type division :: String.t()
  @type game_name :: String.t()
  @type match_id :: String.t()
  @type puuid :: String.t()
  @type queue :: String.t()
  @type region :: String.t()
  @type result :: {:ok, map()} | {:error, map()}
  @type summoner_id :: String.t()
  @type tag_line :: String.t()
  @type tier :: String.t()
  @type timestamp :: non_neg_integer()

  @doc """
  Fetches PUUID for riot_id i.e. tag_line and game_name
  """
  @spec get_account(region(), game_name(), tag_line()) :: result()
  def get_account(region, game_name, tag_line) do
    "#{Base.base_url(region)}/riot/account/v1/accounts/by-riot-id/#{game_name}/#{tag_line}"
    |> Base.request()
    |> Embeds.build(Embeds.Account)
  end

  @doc """
  Fetches all league entries for a region, queue, tier, and division.
  """
  @spec get_league_entries(region(), queue(), tier(), division()) :: result()
  def get_league_entries(region, queue, tier, division) do
    url = "#{Base.base_url(region)}/lol/league/v4/entries/#{queue}/#{tier}/#{division}"
    Base.paginate(url, &Base.request/1)
  end

  @doc """
  Fetches summoner information by their ID.
  """
  @spec get_summoner(region(), summoner_id()) :: result()
  def get_summoner(region, summoner_id) do
    url = "#{Base.base_url(region)}/lol/summoner/v4/summoners/#{summoner_id}"
    Base.request(url)
  end

  @doc """
  Fetches match IDs for the given PUUID within the specified time range.

  Accepts `start_time` and `end_time` in epoch seconds to filter matches.
  """
  @spec get_matches(region(), puuid(), timestamp(), timestamp()) :: result()
  def get_matches(region, puuid, start_time, end_time) do
    url =
      "#{Base.base_url(region)}/lol/match/v5/matches/by-puuid/#{puuid}/ids?startTime=#{start_time}&endTime=#{end_time}&count=100"

    Base.request(url)
  end

  @doc """
  Fetches match details for a given match ID.
  """
  @spec get_match(region(), match_id()) :: result()
  def get_match(region, match_id) do
    url = "#{Base.base_url(region)}/lol/match/v5/matches/#{match_id}"
    Base.request(url)
  end
end
