defmodule SharedUtils.RiotRouting do
  @moduledoc """
  Riot routing information: regions and platforms
  used as routing hosts in Riot API.

  Used for validation in rate-limiting and ecto.
  """

  @type routing_val_t :: atom()

  @americas_platforms ~w(na1 br1 la1 la2)a
  @asia_platforms ~w(jp1 kr)a
  @europe_platforms ~w(me1 eun1 euw1 tr1 ru)a
  @sea_platforms ~w(oc1 ph2 sg2 th2 tw2 vn2)a

  @regions ~w(americas asia europe sea)a

  def routing_vals do
    @americas_platforms ++
      @asia_platforms ++
      @europe_platforms ++
      @sea_platforms ++
      @regions
  end
end
