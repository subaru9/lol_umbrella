defmodule LolWeb.Router do
  use LolWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LolWeb do
    pipe_through :api
  end
end
