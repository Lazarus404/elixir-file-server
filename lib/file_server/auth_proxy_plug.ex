defmodule FileServer.AuthProxyPlug do
  import FileServer.Utils.Parsers

  defmacro __using__(opts \\ []) do
    key = Keyword.get(opts, :key, :default)
    quote do
      def action(conn, _opts) do
        
        apply(
          __MODULE__,
          Plug.Conn.action_name(conn),
          [
            conn,
            conn.params,
            conn.assigns.auth
          ]
        )
      end
    end
  end
end