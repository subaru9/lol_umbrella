defmodule LolApi.Types.RFC1123DateTime do
  @moduledoc """
  Ecto type to handle RFC1123 string
  """
  use Ecto.Type
  require Logger

  def type, do: :utc_datetime

  @spec cast(String.t()) :: {:ok, DateTime.t()} | :error
  def cast(rfc1123_str) when is_binary(rfc1123_str) do
    with {:error, reason} <- Timex.parse(rfc1123_str, "{RFC1123}") do
      Logger.debug(
        "[LolApi.Types.Rfc1123DateTime]: can't cast #{inspect(rfc1123_str)}, reason: #{inspect(reason)}"
      )

      :error
    end
  end

  def cast(rfc1123_str) when is_nil(rfc1123_str) do
    Logger.debug("[LolApi.Types.Rfc1123DateTime]: can't cast nil")
    :error
  end

  def cast(_), do: :error

  def load(term), do: {:ok, term}

  def dump(term), do: {:ok, term}
end
