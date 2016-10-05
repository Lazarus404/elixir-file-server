defmodule FileServer.Utils.Parsers do
  import Joken
  import Plug.Conn

  def sign_token(params) do
    private_key = JOSE.JWK.from_pem_file(Path.join([
      Application.get_env(:file_server, :certs_path), 
      Application.get_env(:file_server, :certs_private_key)
    ]))
    params
    |> token
    |> sign(rs256(private_key))
    |> get_compact
  end

  def verify_token(params) do
    public_key = JOSE.JWK.from_pem_file(Path.join([
      Application.get_env(:file_server, :certs_path), 
      Application.get_env(:file_server, :certs_public_key)
    ]))
    params
    |> token
    |> with_signer(rs256(public_key))
    |> verify
  end

  def verify_function() do
    public_key = JOSE.JWK.from_pem_file(Path.join([
      Application.get_env(:file_server, :certs_path), 
      Application.get_env(:file_server, :certs_public_key)
    ]))
    %Joken.Token{}
    |> token
    |> with_signer(rs256(public_key))
  end

  def verify_user do
    verify_function
    |> with_validation("role", &(
      &1 == "primary" or
      &1 == "secondary" or
      &1 == "tertiary" or
      &1 == "uploader" or
      &1 == "admin" or
      &1 == "sys"
    ))
  end

  def verify_admin do
    verify_function
    |> with_validation("role", &(
      &1 == "uploader" or
      &1 == "admin" or
      &1 == "sys"
    ))
  end

  def send_json(conn, status \\ 200, body \\ "") do
    put_resp_content_type(conn, "application/json")
    |> send_resp(status, Poison.encode!(body))
  end
end