defmodule LolApi.RateLimiter do
  @moduledoc """
  Rate limiter context
  """
  @limit_types [:app, :method]
  @type limit_type :: :app | :method
  @type routing_val :: String.t()
  @type endpoint :: String.t()

  @spec limit_types :: [limit_type()]
  def limit_types, do: @limit_types
end
