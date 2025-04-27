defmodule LolApi.RateLimiter.TTL do
  @moduledoc false

  alias LolApi.RateLimiter.LimitEntry

  require Logger

  @doc """
  Calculates the remaining cooldown TTL (seconds) based on `request_time` and `retry_after`.

  If the cooldown has already expired (TTL < 0), raises an error with diagnostic info.

  Used for enforcing precise cooldown windows in Redis.

  ## Examples

      iex> entry = %LolApi.RateLimiter.LimitEntry{
      ...>   request_time: ~U[2025-04-01 12:00:00Z],
      ...>   retry_after: 120
      ...> }
      iex> DateTime.freeze(~U[2025-04-01 12:01:00Z], fn ->
      ...>   LolApi.RateLimiter.TTL.adjust!(entry)
      ...> end)
      60
  """
  @spec adjust!(LimitEntry.t()) :: non_neg_integer()
  def adjust!(%LimitEntry{retry_after: retry_after, request_time: request_time} = limit_entry)
      when not is_nil(retry_after) do
    ttl =
      request_time
      |> DateTime.add(retry_after, :second)
      |> DateTime.diff(DateTime.utc_now(:second), :second)

    if ttl < 0 do
      msg =
        "Cooldown TTL became negative (#{ttl} seconds left) for entry: #{inspect(limit_entry)}"

      Logger.error(msg)
      raise(msg)
    else
      ttl
    end
  end
end
