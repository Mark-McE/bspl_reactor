defmodule Reactor.Sender do
  # make sender a behaviour with callback to bspl_send/2 as a hook

  import Logger
  use Task

  def start_link(opts) do
    Task.start_link(__MODULE__, :init, opts)
  end

  def init(opts) do
    socket = opts[:socket]
    loop_send(socket)
  end

  defp loop_send(socket) do
    receive do
      map ->
        Task.Supervisor.start_child(
          Reactor.TaskSupervisor,
          fn -> bspl_send(socket, map) end
        )
    end
    loop_send(socket)
  end

  def bspl_send(socket, map) do
    %{"hostname" => host, "port" => port, "message" => message} = map
    packet = Jason.encode!(message)

    :gen_udp.send(socket, host, port, packet)
  end
end
