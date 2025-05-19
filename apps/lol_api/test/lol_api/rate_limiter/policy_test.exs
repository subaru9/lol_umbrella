defmodule LolApi.RateLimiter.PolicyTest do
  @moduledoc false

  use LolApi.RedisCase, async: true

  alias LolApi.RateLimiter.Policy

  describe "&policy_known?/3" do
    test "checks if rate-limiting policy exists in Redis", %{pool_name: pool_name} do
      headers = [
        {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
        {"x-app-rate-limit", "100:120,20:1"},
        {"x-app-rate-limit-count", "20:120,2:1"},
        {"x-method-rate-limit", "50:10"},
        {"x-method-rate-limit-count", "20:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"

      assert {:ok, false} === Policy.known?(routing_val, endpoint, pool_name: pool_name)
      assert :ok === Policy.set(headers, routing_val, endpoint, pool_name: pool_name)
      assert {:ok, true} === Policy.known?(routing_val, endpoint, pool_name: pool_name)
    end
  end

  describe "&fetch/3" do
    test "fetch policy limit keys and parse them into limit entries", %{pool_name: pool_name} do
      headers = [
        {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
        {"x-app-rate-limit", "100:120,20:1"},
        {"x-app-rate-limit-count", "20:120,2:1"},
        {"x-method-rate-limit", "50:10"},
        {"x-method-rate-limit-count", "20:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"

      assert {:ok, false} === Policy.known?(routing_val, endpoint, pool_name: pool_name)
      assert :ok === Policy.set(headers, routing_val, endpoint, pool_name: pool_name)
      {:ok, res} = Policy.fetch(routing_val, endpoint, pool_name: pool_name)
      assert 3 === length(res)
      assert Enum.all?(res, &(&1.count_limit in [50, 20, 100]))
      assert Enum.all?(res, &(&1.window_sec in [120, 1, 10]))
    end
  end

  describe "&enforce/2" do
    test "check keys if count less then limit allow and increment counter, throttle otherwise", %{
      pool_name: pool_name
    } do
      headers = [
        {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
        {"x-app-rate-limit", "100:120,20:1"},
        {"x-app-rate-limit-count", "1:120,1:1"},
        {"x-method-rate-limit", "2:10"},
        {"x-method-rate-limit-count", "0:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"

      assert :ok === Policy.set(headers, routing_val, endpoint, pool_name: pool_name)
      {:ok, limit_entries} = Policy.fetch(routing_val, endpoint, pool_name: pool_name)
      {:allow, _} = Policy.enforce_and_maybe_incr_counter(limit_entries, pool_name: pool_name)
      {:allow, _} = Policy.enforce_and_maybe_incr_counter(limit_entries, pool_name: pool_name)
      {:throttle, [le]} = Policy.enforce_and_maybe_incr_counter(limit_entries, pool_name: pool_name)
      assert :live === le.source
      assert :method === le.limit_type
      assert 2 === le.count_limit
      assert 2 === le.count
    end
  end
end
