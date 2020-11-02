defmodule Reactor.Macros do
  defmacro __using__(_opts) do
    quote location: :keep do
      # Invoke BSPL.Adaptor.Reactor.__before_compile__/1 before the module is compiled
      @before_compile Reactor.Macros
      # Invoke BSPL.Adaptor.Reactor.__after_compile__/2 after the module is compiled
      @after_compile Reactor.Macros

      # register the attribute @functions as an empty list
      Module.register_attribute(__MODULE__, :functions, accumulate: true)

      # TODO: define @callback functions for each message in @messages
      # then, validation would not need to be hardcoded
      # TODO: remove reliance on use BSPL, and implement use BSPL.Reactor

      import Reactor.Macros
    end
  end

  defmacro react(msg_name, do: block) do
    function_name = String.to_atom("react_" <> msg_name)

    quote location: :keep do
      # Prepend the newly defined function to the list of functions
      @functions {unquote(function_name), __MODULE__, unquote(msg_name)}
      def unquote(function_name)(var!(message)), do: unquote(block)
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      def _gen_reactor do
        import BSPL.Parser, only: [received_by: 2, name: 1]

        # validate reactor functions
        expected_functions =
          @messages
          |> received_by(@role)
          |> Enum.map(fn msg -> "react_#{name(msg)}" end)
          |> Enum.sort()
          |> Enum.join(", ")

        actual_functions =
          @functions
          |> Enum.map(fn func -> elem(func, 0) end)
          |> Enum.sort()
          |> Enum.join(", ")

        unless expected_functions == actual_functions do
          raise ArgumentError, "Missing reactor function definitions,
          expected: #{expected_functions},
          got: #{actual_functions}."
        end

        # create reactor module
        reactor_module = Module.concat([BSPL, Protocols, Macro.camelize(@name), Reactor])

        contents =
          Enum.map(@functions, fn {function_name, module, msg_name} ->
            struct_module = Module.concat([BSPL.Schemas, @name, Macro.camelize(msg_name)])
            quote do
              def unquote(function_name)(msg) do
                apply(unquote(module), unquote(function_name), [msg])
              end
              def react(msg = %struct{}) when struct == unquote(struct_module) do
                apply(unquote(module), unquote(function_name), [msg])
              end
            end
          end)

        unless :code.is_loaded(reactor_module) do
          Module.create(reactor_module, contents, Macro.Env.location(__ENV__))
        end
      end
    end
  end

  def __after_compile__(env, _bytecode) do
    apply(env.module, :_gen_reactor, [])
  end
end
