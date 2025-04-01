defmodule SharedUtils.Structs do
  @moduledoc """
  Utility functions for struct manipulation.
  """

  @whitelisted_modules [DateTime, NaiveDateTime, Date, Time]
  @struct_fields [:__meta__]

  @doc """
  Converts a struct to a map, unless the struct belongs to a whitelisted module.

  ## Examples

      iex> struct = %DateTime{year: 2025, month: 1, day: 20, hour: 12, minute: 0, second: 0, time_zone: "Etc/UTC"}
      iex> SharedUtils.Structs.to_map(struct)
      %DateTime{year: 2025, month: 1, day: 20, hour: 12, minute: 0, second: 0, time_zone: "Etc/UTC"}

      iex> struct = %MyStruct{field1: "value1", field2: "value2"}
      iex> SharedUtils.Structs.to_map(struct)
      %{field1: "value1", field2: "value2"}

      iex> SharedUtils.Structs.to_map("not_a_struct")
      "not_a_struct"
  """
  @spec to_map(any()) :: map() | any()
  def to_map(%module{} = struct) when module in @whitelisted_modules do
    struct
  end

  def to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop(@struct_fields)
  end

  def to_map(value), do: value
end
