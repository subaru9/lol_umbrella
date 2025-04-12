defmodule LolApi.RateLimiter.LimitEntry do
  @moduledoc """
  Represents a single rate limit window entry.

  Used by both the bootstrap phase (from Riot headers)
  and the operational phase (from Redis state).
  """
  use Ecto.Schema

  import Ecto.Changeset,
    only: [cast: 3, validate_inclusion: 3, update_change: 3, validate_number: 3, apply_action!: 2]

  alias LolApi.RateLimiter

  @type limit_type :: :app | :method
  @type t :: %{
          optional(:limit_type) => limit_type(),
          optional(:window_sec) => pos_integer(),
          optional(:count_limit) => pos_integer(),
          optional(:count) => non_neg_integer(),
          optional(:request_time) => String.t(),
          optional(:retry_after) => pos_integer()
        }

  @available_fields ~w(
    limit_type
    window_sec
    count_limit
    count
    request_time
  )a

  @primary_key false
  embedded_schema do
    field :limit_type, :string
    field :window_sec, :integer
    field :count_limit, :integer
    field :count, :integer, default: 0
    field :request_time, LolApi.Types.RFC1123DateTime
    field :retry_after, :integer
  end

  def changeset(%__MODULE__{} = limit_entry, attrs \\ %{}) do
    limit_entry
    |> cast(attrs, @available_fields)
    |> update_change(:limit_type, &String.to_existing_atom/1)
    |> validate_inclusion(:limit_type, RateLimiter.limit_types())
    |> validate_number(:window_sec, greater_than: 0)
    |> validate_number(:count_limit, greater_than: 0)
    |> validate_number(:count, greater_than_or_equal: 0)
  end

  @doc """
  If something wrong with Riont's headers or Redis cache,
  let's surface bugs early!
  """
  def create!(attrs) do
    attrs
    |> changeset()
    |> apply_action!(:insert)
    |> SharedUtils.Structs.to_map()
  end
end
