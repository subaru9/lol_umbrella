defmodule LolApi.RateLimiter.CooldownTest do
  @moduledoc false

  use LolApi.RedisCase, async: true
  doctest LolApi.RateLimiter.Cooldown

  alias LolApi.RateLimiter.Cooldown

  describe "&maybe_set/4" do
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

    test "missing required headers, skip cooldown key", %{pool_name: pool_name} do
      headers = [{"date", "Tue, 02 Apr 2025 18:00:00 GMT"}]

      routing_val = "euw1"
      endpoint = "/lol/summoner"
      fixed_now = ~U[2025-04-02 18:01:00Z]

      assert Cooldown.maybe_set(headers, routing_val, endpoint,
               pool_name: pool_name,
               now: fixed_now
             ) === :ok

      {:allow, [_limit_entry]} = Cooldown.status(routing_val, endpoint, pool_name: pool_name)
    end
  end

  describe "&status/3" do
    test "no cooldown, allow request", %{pool_name: pool_name} do
      routing_val = "euw1"
      endpoint = "/lol/summoner"

      {:allow, [_limit_entry]} = Cooldown.status(routing_val, endpoint, pool_name: pool_name)
    end

    test "multiple cooldowns, the one with the biggest TTL is choosen", %{pool_name: pool_name} do
      routing_val = "euw1"
      endpoint = "/lol/summoner"
      fixed_now = ~U[2025-04-02 18:00:01Z]

      headers = [
        {"x-rate-limit-type", "application"},
        {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
        {"retry-after", "120"}
      ]

      assert Cooldown.maybe_set(headers, routing_val, endpoint,
               pool_name: pool_name,
               now: fixed_now
             ) === :ok

      headers = [
        {"x-rate-limit-type", "service"},
        {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
        {"retry-after", "240"}
      ]

      assert Cooldown.maybe_set(headers, routing_val, endpoint,
               pool_name: pool_name,
               now: fixed_now
             ) === :ok

      headers = [
        {"x-rate-limit-type", "method"},
        {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
        {"retry-after", "60"}
      ]

      assert Cooldown.maybe_set(headers, routing_val, endpoint,
               pool_name: pool_name,
               now: fixed_now
             ) === :ok

      {:throttle, [limit_entry]} = Cooldown.status(routing_val, endpoint, pool_name: pool_name)
      assert limit_entry.ttl === 239
      assert limit_entry.limit_type === :service
    end
  end
end
