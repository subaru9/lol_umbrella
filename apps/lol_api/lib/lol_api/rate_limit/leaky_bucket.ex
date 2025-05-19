defmodule LolApi.RateLimit.LeakyBucket do
  use GenServer

  require Logger

  # def start_link(name, opts) do
  #   GenServer.start_link(__MODULE__, opts, name: name)
  # end

  def wait_for_turn(name) do
    GenServer.call(name, :wait_for_turn, :infinity)
  end

  def init(opts) do
    requests_per_second =
      Keyword.fetch!(opts, :requests_per_second)

    request_pop_in_ms =
      floor(:timer.seconds(1) / requests_per_second)

    state = %{
      queue: :queue.new(),
      queue_length: 0,
      requests_per_second: requests_per_second,
      request_pop_in_ms: request_pop_in_ms
    }

    {:ok, state}
  end

  def handle_call(
        :wait_for_turn,
        from,
        %{queue_length: original_queue_length, queue: queue} = state
      ) do
    updated_queue = :queue.in(from, queue)
    Logger.debug("[RateLimit.LeakyBucket] Request added to queue: #{inspect(from)}")

    updated_state =
      state
      |> Map.put(:queue, updated_queue)
      |> Map.put(:queue_length, original_queue_length + 1)

    # queue transition from 0 to 1
    if original_queue_length === 0 do
      {:noreply, updated_state, {:continue, :schedule_processing_cycle}}
    else
      {:noreply, updated_state}
    end
  end

  def handle_continue(:schedule_processing_cycle, state) do
    Process.send_after(self(), :pop_request, state.request_pop_in_ms)

    {:noreply, state}
  end

  def handle_info(:pop_request, %{queue_length: 0} = state) do
    {:noreply, state}
  end

  def handle_info(:pop_request, %{queue_length: queue_length, queue: queue} = state) do
    {{:value, requesting_process}, updated_queue} = :queue.out(queue)

    GenServer.reply(requesting_process, :ok)
    Logger.debug("[RateLimit.LeakyBucket] Request processed: #{inspect(requesting_process)}")

    updated_state =
      state
      |> Map.put(:queue, updated_queue)
      |> Map.put(:queue_length, queue_length - 1)

    {:noreply, updated_state, {:continue, :schedule_processing_cycle}}
  end
end
