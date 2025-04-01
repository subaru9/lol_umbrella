defmodule LolApi.Embeds.Account do
  use Ecto.Schema
  import Ecto.Changeset, only: [cast: 3, validate_required: 2]

  @available_fields ~w(puuid game_name tag_line)a
  @required_fields ~w(puuid game_name tag_line)a

  @primary_key false
  embedded_schema do
    field :puuid, :string
    field :game_name, :string
    field :tag_line, :string
  end

  def changeset(%__MODULE__{} = account, attrs \\ %{}) do
    account
    |> cast(attrs, @available_fields)
    |> validate_required(@required_fields)
  end
end
