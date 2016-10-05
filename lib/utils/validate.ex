defmodule FileServer.Utils.Validate do
  @behaviour Plug

  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, params \\ :user) do
    IO.inspect conn
    case conn.private do
      {:ok, claims} ->
        do_validate(conn, claims, params)
      r ->
        IO.inspect r
        invalid(conn)
    end
    conn
  end

  defp do_validate(conn, %{"pem" => %{"user" => _}}, params) when params == :user do
    conn
  end
  defp do_validate(conn, %{"pem" => %{"uploader" => _}}, params) when params in [:user, :uploader] do
    conn
  end
  defp do_validate(conn, %{"pem" => %{"admin" => _}}, params) when params in [:user, :uploader, :admin] do
    conn
  end
  defp do_validate(conn, %{"pem" => %{"sys" => _}}) do
    conn
  end
  defp do_validate(conn, _) do
    invalid(conn)
  end

  defp invalid(conn) do
    conn
    |> send_resp(401, "")
    |> halt
  end
end