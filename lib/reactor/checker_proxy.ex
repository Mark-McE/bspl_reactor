defmodule Reactor.CheckerProxy do
  @moduledoc """
    An API for communicating with the checker in a transparent manner
  """

  defmacro __using__(opts) do

    quote location: :keep do
      def enabled_messages() do
        GenServer.call(Reactor.CheckerProxyWorker, {:enabled_messages})
      end

      def send_message({agent_host, agent_port}, msg_map) do
        GenServer.call(Reactor.CheckerProxyWorker, {:send, {agent_host, agent_port}, msg_map})
      end
    end
  end
end
