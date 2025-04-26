defmodule LolApi.RateLimiter.LimitEntry do
  @moduledoc """
  Defines the canonical structure for a single rate-limit rule.

  Used throughout the system to represent limits from any source —
  whether parsed from Riot headers (bootstrap) or fetched from Redis keys (operational).

  Each `%LimitEntry{}` describes:

    • Which `{routing_val, endpoint, limit_type}` it applies to
    • The window size (`window_sec`) in seconds
    • How many requests are allowed (`count_limit`)
    • How many requests have occurred so far (`count`)
    • Optional metadata from the original response (`request_time`, `retry_after`)

  This struct is used by all rate-limiting modules:
    - `HeaderParser`: parses Riot headers into entries
    - `RedisCommand`: serializes entries to Redis
    - `KeyBuilder`: generates keys from entries
    - `KeyValueParser`: parses Redis keys into entries
    - `Counter`: enforces limits using entries

  It is the shared language of the rate-limiting system.
  """
  use Ecto.Schema

  import Ecto.Changeset,
    only: [cast: 3, validate_number: 3, apply_action!: 2]

  alias LolApi.RateLimiter.Counter
  alias SharedUtils.RiotRouting

  @type limit_type :: :app | :method
  @type t :: %__MODULE__{
          routing_val: RiotRouting.routing_val_t() | nil,
          endpoint: String.t() | nil,
          limit_type: Counter.limit_type() | nil,
          window_sec: pos_integer() | nil,
          count_limit: pos_integer() | nil,
          count: non_neg_integer(),
          request_time: DateTime.t() | nil,
          retry_after: pos_integer() | nil
        }

  @type attrs :: %{
          optional(:routing_val) => RiotRouting.routing_val_t() | String.t(),
          optional(:endpoint) => String.t(),
          optional(:limit_type) => Counter.limit_type() | String.t(),
          optional(:window_sec) => pos_integer() | String.t(),
          optional(:count_limit) => pos_integer() | String.t(),
          optional(:count) => non_neg_integer() | String.t(),
          optional(:request_time) => String.t(),
          optional(:retry_after) => pos_integer() | String.t()
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
    field :limit_type, Ecto.Enum, values: Counter.limit_types()

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
    |> validate_number(:count, greater_than_or_equal_to: 0)
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

  def update!(entry, attrs) do
    entry
    |> changeset(attrs)
    |> apply_action!(:update)
  end
end
