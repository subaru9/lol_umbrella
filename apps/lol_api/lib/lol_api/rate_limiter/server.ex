# defmodule LolApi.RateLimiter.Server do
#   use GenServer
#
#   def start_link(name, args) do
#     GenServer.start_link(__MODULE__, args, name: name)
#   end
#
#   def init(_args) do
#     state = %{
#       queue: :queue.new(),
#       queue_length: 0
#     }
#
#     {:ok, state}
#   end
#
#   def handle_call(:maybe_trottle, from, state) do
#     if retry_after_ms > 0 do
#     else
#       
#     end
#     
#   end
# end
