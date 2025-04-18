defmodule LolApi.RateLimiter.LimitEntry do
  @moduledoc """
  Represents a single rate limit window entry.

  Used by both the bootstrap phase (from Riot headers)
  and the operational phase (from Redis state),
  header parsing, Redis I/O and rate logic
  """
  use Ecto.Schema

  import Ecto.Changeset,
    only: [cast: 3, validate_inclusion: 3, update_change: 3, validate_number: 3, apply_action!: 2]

  alias SharedUtils.RiotRouting
  alias LolApi.RateLimiter

  @type limit_type :: :app | :method
  @type t :: %{
          optional(:limit_type) => limit_type(),
          optional(:window_sec) => pos_integer(),
          optional(:count_limit) => pos_integer(),
          optional(:count) => non_neg_integer(),
          optional(:request_time) => String.t(),
          optional(:retry_after) => pos_integer(),
          optional(:routing_val) => String.t(),
          optional(:endpoint) => String.t()
        }

  @available_fields ~w(
    limit_type
    window_sec
    count_limit
    count
    request_time
    retry_after
    routing_val
    endpoint
  )a

  @primary_key false
  embedded_schema do
    field :endpoint, :string
    field :routing_val, Ecto.Enum, values: RiotRouting.routing_vals()
    field :limit_type, Ecto.Enum, values: RateLimiter.limit_types()

    field :window_sec, :integer
    field :count_limit, :integer
    field :count, :integer, default: 0

    field :request_time, LolApi.Types.RFC1123DateTime
    field :retry_after, :integer
  end

  def changeset(%__MODULE__{} = limit_entry, attrs \\ %{}) do
    limit_entry
    |> cast(attrs, @available_fields)
    |> validate_number(:window_sec, greater_than: 0)
    |> validate_number(:count_limit, greater_than: 0)
    |> validate_number(:count, greater_than_or_equal: 0)
  end

  @doc """
  If something is wrong with Riot's headers or Redis cache,
  this function raises early.

  ## Examples

      iex> attrs = %{
      ...>   "limit_type" => "app",
      ...>   "window_sec" => 120,
      ...>   "count_limit" => 100,
      ...>   "count" => 0,
      ...>   "request_time" => "Tue, 01 Apr 2025 18:15:26 GMT"
      ...> }
      iex> LolApi.RateLimiter.LimitEntry.create!(attrs)
      %{
        limit_type: :app,
        window_sec: 120,
        count_limit: 100,
        count: 0,
        request_time: ~U[2025-04-01 18:15:26Z]
      }

  """
  @spec create!(map()) :: t()
  def create!(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end
end
