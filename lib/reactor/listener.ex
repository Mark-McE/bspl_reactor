defmodule Reactor.Listener do
  import Logger
  use Task

  def start_link(opts) do
    Task.start_link(__MODULE__, :init, opts)
  end

  def init(opts) do
    socket = opts[:socket]
    reactor_module = opts[:module]
    loop_listen(socket, reactor_module)
  end

  defp loop_listen(socket, reactor_module) do
    case :gen_udp.recv(socket, 0) do
      {:ok, {_ip, _port, data}} ->
        Task.Supervisor.start_child(
          Reactor.TaskSupervisor,
          fn -> dispatch(reactor_module, data) end
        )

      {:error, reason} ->
        warn("Error receiving message from UDP socket: #{reason}")
    end

    loop_listen(socket, reactor_module)
  end

  def dispatch(reactor_module, msg_json) do
    {msg_name, msg_map} =
      Jason.decode!(msg_json)
      |> Map.pop("bspl_message_name")

    function_name = String.to_atom("react_" <> msg_name)

    # call the function in the reactor for this message
    apply(reactor_module, function_name, [msg_map])
  end
end
