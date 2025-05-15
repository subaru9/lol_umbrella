defmodule LolApi.RateLimiter.CooldownTest do
  @moduledoc false

  use LolApi.RedisCase, async: true
  doctest LolApi.RateLimiter.Cooldown

  alias LolApi.RateLimiter.Cooldown

  describe "&maybe_set/3" do
    test "having all required headers sets the cooldown key", %{pool_name: pool_name} do
      headers = [
        {"x-rate-limit-type", "application"},
        {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
        {"retry-after", "120"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"
      fixed_now = ~U[2025-04-02 18:01:00Z]

      assert Cooldown.maybe_set(headers, routing_val, endpoint,
               pool_name: pool_name,
               now: fixed_now
             ) === :ok

      {:throttle, [limit_entry]} = Cooldown.status(routing_val, endpoint, pool_name: pool_name)
      assert limit_entry.ttl === 60
    end
  end
end
