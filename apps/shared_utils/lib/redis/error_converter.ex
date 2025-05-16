defmodule SharedUtils.Redis.Error do
  @moduledoc """
  Converts various error structures into consistent `ErrorMessage.t()` format.
  """

  @spec to_error_message(Redix.ConnectionError.t()) :: ErrorMessage.t()
  @spec to_error_message(Redix.Error.t()) :: ErrorMessage.t()
  @spec to_error_message(any()) :: ErrorMessage.t()
  def to_error_message(%{__struct__: Redix.ConnectionError, reason: reason}) do
    ErrorMessage.internal_server_error("Redis connection error", reason)
  end

  def to_error_message(%{__struct__: Redix.Error, message: message}) do
    ErrorMessage.internal_server_error("Redis command error", message)
  end

  def to_error_message(other) do
    ErrorMessage.internal_server_error("Unknown error", other)
  end
end
