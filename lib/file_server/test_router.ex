defmodule FileServer.TestRouter do
  use Plug.Router

  import FileServer.Utils.Parsers
  import Plug.Conn

  # plug FileServer.Utils.Validate
  plug :match
  plug :dispatch

  get "/token" do
    token = create_token_from_params(conn)
    send_json(conn, 200, %{token: token})
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  def create_token_from_params(conn) do
    conn = conn
    |> fetch_query_params
    |> parse_authentication_request

    sign_token(conn.assigns.auth)
  end

  def create_token(email, role, host) do
    sign_token(%{email: email, role: role, host: host})
  end

  defp parse_authentication_request(conn = %Plug.Conn{params: %{"email" => email, "role" => role, "host" => host}}) do
    Plug.Conn.assign(conn, :auth, %{email: email, role: role, host: host})
  end
end