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

  def handle_call({:send, agent, msg_map}, _from, state) do
    socket = state[:socket]
    checker_host = state[:checker_host]
    checker_port = state[:checker_port]
    msg_json = Jason.encode!(msg_map)
    agent_host = System.get_env("BSPL_AGENT_#{agent}_HOST")
    agent_port = System.get_env("BSPL_AGENT_#{agent}_PORT")

    # send to my checker
    :gen_udp.send(socket, checker_host, checker_port, msg_json)
    # send to other agent's checker
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
