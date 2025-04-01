defmodule LolApi.Embeds do
  @doc """
  Applies basic normalisation, 
  stricter validation expected on db level
  """
  def build({:ok, attrs}, module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :changeset, 2) do
      account =
        module
        |> apply(:changeset, [struct(module), attrs])
        |> Ecto.Changeset.apply_changes()
        |> SharedUtils.Structs.to_map()

      {:ok, account}
    else
      {:error,
       ErrorMessage.internal_server_error(
         "[LolApi.Embeds] #{module} does not implement changeset/2 function"
       )}
    end
  end

  def build({:error, _error_message} = error, _module), do: error
end
