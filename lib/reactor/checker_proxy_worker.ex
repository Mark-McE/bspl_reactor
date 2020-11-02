defmodule Reactor.CheckerProxyWorker do

  use GenServer

  def start_link(state) do
    IO.inspect(state)

    GenServer.start_link(__MODULE__, state, name: Reactor.CheckerProxyWorker)
  end

  def init(opts) do
    socket = opts[:socket]
    checker_host = opts[:checker_host]
    checker_port = opts[:checker_port]

    {:ok, %{socket: socket, checker_host: checker_host, checker_port: checker_port}}
  end

  def handle_call({:send, {agent_host, agent_port}, msg_map}, _from, state) do
    socket = state[:socket]
    msg_json = Jason.encode!(msg_map)

    :gen_udp.send(socket, agent_host, agent_port, msg_json)

    {:reply, :ok, state}
  end

  def handle_call({:enabled_messages}, _from, state) do
    socket = state[:socket]
    checker_host = state[:checker_host]
    checker_port = state[:checker_port]

    :gen_udp.send(socket, checker_host, checker_port, "enabled_messages")

    data = case :gen_udp.recv(socket, 0) do
      {:ok, {_ip, _port, data}} -> data
    end

    {:reply, Jason.decode!(data), state}
  end
end
