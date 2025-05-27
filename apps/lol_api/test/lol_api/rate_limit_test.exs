defmodule LolApi.RateLimitTest do
  @moduledoc false
  use LolApi.RedisCase

  alias LolApi.RateLimit
  alias LolApi.RateLimit.{Cooldown, Policy}

  describe "&hit/3" do
    test "allows request with known policy, cooldown, withing limit", %{pool_name: pool_name} do
      headers = [
        {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
        {"x-app-rate-limit", "100:120,20:1"},
        {"x-app-rate-limit-count", "20:120,2:1"},
        {"x-method-rate-limit", "50:10"},
        {"x-method-rate-limit-count", "20:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"

      :ok = Policy.set(headers, routing_val, endpoint, pool_name: pool_name)

      expected =
        {:allow,
         [
           %LolApi.RateLimit.LimitEntry{
             endpoint: "/lol/summoner",
             routing_val: :euw1,
             limit_type: :application,
             window_sec: 120,
             count_limit: 100,
             count: 1,
             request_time: nil,
             retry_after: nil,
             ttl: 120,
             adjusted_ttl: nil,
             source: :live
           },
           %LolApi.RateLimit.LimitEntry{
             endpoint: "/lol/summoner",
             routing_val: :euw1,
             limit_type: :application,
             window_sec: 1,
             count_limit: 20,
             count: 1,
             request_time: nil,
             retry_after: nil,
             ttl: 1,
             adjusted_ttl: nil,
             source: :live
           },
           %LolApi.RateLimit.LimitEntry{
             endpoint: "/lol/summoner",
             routing_val: :euw1,
             limit_type: :method,
             window_sec: 10,
             count_limit: 50,
             count: 1,
             request_time: nil,
             retry_after: nil,
             ttl: 10,
             adjusted_ttl: nil,
             source: :live
           }
         ]}

      assert expected === RateLimit.hit(routing_val, endpoint, pool_name: pool_name)
    end

    test "throttle after exceeding the counter policy", %{pool_name: pool_name} do
      headers = [
        {"date", "Tue, 01 Apr 2025 18:15:26 GMT"},
        {"x-app-rate-limit", "100:120,2:1"},
        {"x-app-rate-limit-count", "20:120,0:1"},
        {"x-method-rate-limit", "50:10"},
        {"x-method-rate-limit-count", "20:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"

      expected =
        {:throttle,
         [
           %LolApi.RateLimit.LimitEntry{
             endpoint: "/lol/summoner",
             routing_val: :euw1,
             limit_type: :application,
             window_sec: 1,
             count_limit: 2,
             count: 2,
             request_time: nil,
             retry_after: nil,
             ttl: 1,
             adjusted_ttl: nil,
             source: :live
           }
         ]}

      :ok = Policy.set(headers, routing_val, endpoint, pool_name: pool_name)
      RateLimit.hit(routing_val, endpoint, pool_name: pool_name)
      RateLimit.hit(routing_val, endpoint, pool_name: pool_name)

      assert expected === RateLimit.hit(routing_val, endpoint, pool_name: pool_name)
    end
  end

  test "throttle if cooldown is set", %{pool_name: pool_name} do
    headers = [
      {"x-rate-limit-type", "application"},
      {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
      {"retry-after", "120"}
    ]

    routing_val = "euw1"
    endpoint = "/lol/summoner"
    fixed_now = ~U[2025-04-02 18:00:01Z]

    expected =
      {:throttle,
       [
         %LolApi.RateLimit.LimitEntry{
           endpoint: nil,
           routing_val: :euw1,
           limit_type: :application,
           window_sec: nil,
           count_limit: nil,
           count: 0,
           request_time: nil,
           retry_after: nil,
           ttl: 119,
           adjusted_ttl: nil,
           source: :cooldown
         }
       ]}

    :ok = Cooldown.maybe_set(headers, routing_val, endpoint, pool_name: pool_name, now: fixed_now)

    assert expected === RateLimit.hit(routing_val, endpoint, pool_name: pool_name)
  end

  test "allow blind request if policy unknown", %{pool_name: pool_name} do
    routing_val = "euw1"
    endpoint = "/lol/summoner"

    {:ok, false} = Policy.known?(routing_val, endpoint, pool_name: pool_name)

    expected =
      {:allow,
       [
         %LolApi.RateLimit.LimitEntry{
           endpoint: "/lol/summoner",
           routing_val: :euw1,
           limit_type: nil,
           window_sec: nil,
           count_limit: nil,
           count: 0,
           request_time: nil,
           retry_after: nil,
           ttl: nil,
           adjusted_ttl: nil,
           source: :policy
         }
       ]}

    assert expected === RateLimit.hit(routing_val, endpoint, pool_name: pool_name)
  end

  describe "&refresh/4" do
    test "sets cooldown before policy check to avoid not setting it when policy is unknown", %{
      pool_name: pool_name
    } do
      headers = [
        {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
        {"retry-after", "120"},
        {"x-rate-limit-type", "application"},
        {"x-app-rate-limit", "100:120,2:1"},
        {"x-app-rate-limit-count", "20:120,3:1"},
        {"x-method-rate-limit", "50:10"},
        {"x-method-rate-limit-count", "20:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"
      fixed_now = ~U[2025-04-02 18:00:01Z]

      expected =
        {:throttle,
         [
           %LolApi.RateLimit.LimitEntry{
             endpoint: nil,
             routing_val: :euw1,
             limit_type: :application,
             window_sec: nil,
             count_limit: nil,
             count: 0,
             request_time: nil,
             retry_after: nil,
             ttl: 119,
             adjusted_ttl: nil,
             source: :cooldown
           }
         ]}

      {:ok, _limit_entries} =
        RateLimit.refresh(headers, routing_val, endpoint, pool_name: pool_name, now: fixed_now)

      assert expected === Cooldown.status(routing_val, endpoint, pool_name: pool_name)
    end

    test "handles expired cooldown", %{pool_name: pool_name} do
      headers = [
        {"date", "Tue, 02 Apr 2025 18:00:00 GMT"},
        {"retry-after", "120"},
        {"x-rate-limit-type", "application"},
        {"x-app-rate-limit", "100:120,2:1"},
        {"x-app-rate-limit-count", "20:120,3:1"},
        {"x-method-rate-limit", "50:10"},
        {"x-method-rate-limit-count", "20:10"}
      ]

      routing_val = "euw1"
      endpoint = "/lol/summoner"
      fixed_now = ~U[2025-04-02 18:02:00Z]

      expected =
        {:allow,
         [
           %LolApi.RateLimit.LimitEntry{
             endpoint: "/lol/summoner",
             routing_val: :euw1,
             limit_type: nil,
             window_sec: nil,
             count_limit: nil,
             count: 0,
             request_time: nil,
             retry_after: nil,
             ttl: nil,
             adjusted_ttl: nil,
             source: :cooldown
           }
         ]}

      {:ok, _limit_entries} =
        RateLimit.refresh(headers, routing_val, endpoint, pool_name: pool_name, now: fixed_now)

      assert expected === Cooldown.status(routing_val, endpoint, pool_name: pool_name)
    end
  end
end
