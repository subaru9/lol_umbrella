defmodule SharedUtils.JSON do
  @moduledoc """
  Mostly Elixir's JSON decoders.
  """

  alias SharedUtils.{Strings, Structs}

  @doc """
  Decodes a JSON string into an Elixir map, applying custom normalization.

  ## Examples

      iex> json = ~s({"gameName": "example_game", "tagLine": "example_tag"})
      iex> {:ok, decoded} = SharedUtils.JSON.decode(json)
      iex> decoded
      %{game_name: "example_game", tag_line: "example_tag"}
  """
  @spec decode(String.t()) :: {:ok, map()} | {:error, any()}
  def decode(json) do
    case JSON.decode(json, [], object_push: &object_push/3) do
      {decoded, _acc, _rest} ->
        {:ok, decoded}

      {:error, reason} ->
        {:error,
         ErrorMessage.internal_server_error(
           "[SharedUtils.JSON] JSON decode failed: #{inspect(reason)}.",
           json: json
         )}
    end
  end

  defp object_push(key, value, acc) do
    [{normalize_key(key), normalize_val(value)} | acc]
  end

  defp normalize_key(key) do
    key
    |> Macro.underscore()
    |> Strings.to_maybe_existing_atom()
  end

  defp normalize_val(val) do
    Structs.to_map(val)
  end
end
