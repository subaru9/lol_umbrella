defmodule LolApi.RateLimiter do
  @moduledoc """
  RateLimiter context for delegating rate-limiting operations
  to the configured limiter type.
  """

  @config Application.compile_env(:lol_api, :rate_limiter, %{
            limiter_type: LolApi.RateLimiter.LeakyBucket,
            requests_per_second: 0.83
          })

  @type local_name :: atom()
  @type global_name :: {:global, local_name()}

  @spec start_link(global_name()) :: GenServer.on_start()
  def start_link(name) do
    limiter_type().start_link(name, limiter_opts())
  end

  @spec wait_for_turn(global_name()) :: term() 
  def wait_for_turn(name) do
    limiter_type().wait_for_turn(name)
  end

  defp limiter_type do
    @config[:limiter_type]
  end

  defp limiter_opts do
    [requests_per_second: @config[:requests_per_second]]
  end
end
