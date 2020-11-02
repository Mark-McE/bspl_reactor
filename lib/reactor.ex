defmodule Reactor do
  @moduledoc """
  Defines the BSPL Supervision tree.

  When used, BSPL expects `:protocol_path`, `:role` and `:repo` as required
  parameters, and can take `:port` as an optional parameter.

  `:protocol_path`: the file path to the BSPL protocol
  `:role`: the BSPL role for this agent
  `:repo`: the `Ecto.Repo` module to store the local state
  `:port`: the port this agent will receive messages on

  For example:
      defmodule Labeller.BSPL do
        use Reactor,
          protocol_path: "priv/logistics.bspl",
          role: "Labeller",
          repo: Labeller.Repo,
          port: 9898
      end
  """

  defmacro __using__(opts) do
    port = System.get_env("BSPL_PORT") || "9990"
    host = System.get_env("BSPL_CHECKER_HOST") || "localhost"
    c_port = System.get_env("BSPL_CHECKER_PORT") || "9992"

    port = String.to_integer(port)
    host = String.to_charlist(host)
    c_port = String.to_integer(c_port)

    {protocol_name,
      [
        roles: _,
        params: _,
        messages: messages
      ]} = BSPL.Parser.parse!(opts[:protocol_path])

    reactor_module = Module.concat([BSPL, Protocols, Macro.camelize(protocol_name), Reactor])

    quote location: :keep, bind_quoted: [
            opts: opts,
            port: port,
            name: protocol_name,
            messages: Macro.escape(messages),
            reactor_module: reactor_module,
            checker_host: host,
            checker_port: c_port
          ] do
      @name name
      @port port
      @messages messages
      @role opts[:role]
      @reactor_module reactor_module
      @checker_host checker_host
      @checker_port checker_port

      use Reactor.Macros
      use Supervisor

      def start_link(opts) do
        Supervisor.start_link(__MODULE__, :ok, opts)
      end

      @impl true
      def init(:ok) do
        # active false - messages must be received from a blocking call to :gen_udp.recv/2
        # instead of incoming messages being sent to this process's mailbox
        {:ok, socket1} = :gen_udp.open(@port, [{:active, false}])
        {:ok, socket2} = :gen_udp.open(@port + 1, [{:active, false}])

        checker_proxy = create_checker_proxy()

        children = [
          {Task.Supervisor, name: BSPL.TaskSupervisor},
          {Reactor.Listener, [[socket: socket1, module: @reactor_module]]},
#          {Reactor.Sender, [[socket: socket2, module: @reactor_module]], name: Sender},
          {Reactor.CheckerProxyWorker, [socket: socket2, checker_host: @checker_host, checker_port: @checker_port]}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      defp create_checker_proxy do
        module_name = Macro.camelize(@name) |> List.wrap() |> Module.concat()
        contents = quote do: use(Reactor.CheckerProxy)
        Module.create(module_name, contents, Macro.Env.location(__ENV__))

        module_name
      end
    end
  end
end
