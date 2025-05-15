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
      iex> LolApi.RateLimiter.TTL.adjust!(entry, ~U[2025-04-01 12:01:00Z])
      60
  """
  @spec adjust!(LimitEntry.t(), DateTime.t()) :: non_neg_integer()
  def adjust!(
        %LimitEntry{retry_after: retry_after, request_time: request_time} = limit_entry,
        utc_now_sec \\ DateTime.utc_now(:second)
      )
      when not is_nil(retry_after) and not is_nil(request_time) do
    ttl =
      request_time
      |> DateTime.add(retry_after, :second)
      |> DateTime.diff(utc_now_sec, :second)

    # This should never happen unless headers are malformed or `now` is behind request time
    if ttl < 0 do
      msg =
        """
        [LolApi.RateLimiter.TTL] Cooldown TTL became negative (#{ttl} seconds). 
        Details: 
        Riot's request time: #{inspect(limit_entry, pretty: true)}
        The time it hit this function: #{inspect(utc_now_sec)}
        """

      Logger.error(msg)
      raise(msg)
    else
      ttl
    end
  end
end
