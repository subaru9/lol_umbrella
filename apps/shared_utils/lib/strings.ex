defmodule SharedUtils.Strings do
  @moduledoc """
  Utility functions for string manipulation.
  """

  @doc """
  Converts a binary string to an existing atom if it exists, or creates a new atom if it doesn't.

  ## Examples

      iex> SharedUtils.Strings.to_maybe_existing_atom("new_atom")
      :new_atom
  """
  @spec to_maybe_existing_atom(String.t() | atom()) :: atom()
  def to_maybe_existing_atom(atom) when is_atom(atom), do: atom

  def to_maybe_existing_atom(string) when is_binary(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError ->
      String.to_atom(string)
  end
end
