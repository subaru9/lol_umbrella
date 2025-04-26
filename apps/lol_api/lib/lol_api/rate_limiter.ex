defmodule LolApi.RateLimiter do
  @moduledoc """
  Rate limiter context
  """
  @limit_types [:app, :method]
  @type limit_type :: :app | :method

  @spec limit_types :: [limit_type()]
  def limit_types, do: @limit_types
end
