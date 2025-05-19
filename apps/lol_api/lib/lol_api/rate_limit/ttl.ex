defmodule LolApi.RateLimit.TTL do
  @moduledoc false

  alias LolApi.Config
  alias LolApi.RateLimit.LimitEntry

  require Logger

  @doc """
  Calculates the remaining cooldown TTL (seconds) based on `request_time` and `retry_after`.

  If the cooldown has already expired (TTL < 0), raises an error with diagnostic info.

  Used for enforcing precise cooldown windows in Redis.

  ## Examples

      iex> entry = %LolApi.RateLimit.LimitEntry{
      ...>   request_time: ~U[2025-04-01 12:00:00Z],
      ...>   retry_after: 120
      ...> }
      iex> LolApi.RateLimit.TTL.adjust(entry, ~U[2025-04-01 12:01:00Z])
      60
  """
  @spec adjust(LimitEntry.t(), DateTime.t()) ::
          {:ok, non_neg_integer()} | {:error, atom() | ErrorMessage.t()}
  def adjust(
        %LimitEntry{retry_after: retry_after, request_time: request_time} = limit_entry,
        utc_now_sec \\ DateTime.utc_now(:second)
      )
      when not is_nil(retry_after) and not is_nil(request_time) do
    ttl =
      request_time
      |> DateTime.add(retry_after, :second)
      |> DateTime.diff(utc_now_sec, :second)

    cond do
      ttl <= 0 or ttl > Config.max_cooldown_ttl() ->
        msg =
          """
          [LolApi.RateLimit.TTL] Cooldown TTL is invalid. 
          Details:\n 
          Limit Entry: #{inspect(limit_entry, pretty: true)},\n
          The time it hit this function: #{inspect(utc_now_sec)},\n
          TTl: #{inspect(ttl)},\n
          Max cooldown TTL: #{Config.max_cooldown_ttl()} 
          """

        Logger.warning(msg)

        {:error, :ttl_invalid}

      ttl > 0 ->
        {:ok, ttl}
    end
  end
end
