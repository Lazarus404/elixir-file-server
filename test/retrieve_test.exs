defmodule RetrieveTest do
  use ExUnit.Case
  use Plug.Test
  
  alias FileServer.Router
  alias FileServer.TestRouter

  @opts Router.init([])

  @email "lee.sylvester@gmail.com"
  @role "uploader"
  @user_role "primary"
  @host "stompondlane"

  @path "primary"

  @type_asset "asset"
  @type_file "file"
  
  @asset "example.png"
  
  @example_file "test/fixtures/#{@asset}"

  @bad_token "Bad Token"
  
  setup do
    path = Router.get_path(@type_file)
    if File.exists?(path) do
      File.rm_rf!(path)
    end
    path = Router.get_path(@type_asset)
    if File.exists?(path) do
      File.rm_rf!(path)
    end
    {:ok, %{token: TestRouter.create_token(@email, @role, @host), user_token: TestRouter.create_token(@email, @user_role, @host)}}
  end


  test "user retrieval of uploaded file", %{token: token, user_token: user_token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)
    conn = fetch_file(user_token, "#{@type_file}/#{@path}/#{@asset}")

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    
    assert conn.state == :chunked
    assert conn.status == 200

    assert File.exists?(path)
    assert conn.resp_body == File.read!(path)
  end


  test "failing unauthorised retrieval of uploaded file", %{token: token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)
    conn = fetch_file(@bad_token, "#{@type_file}/#{@path}/#{@asset}")

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(path)
  end


  test "user retrieval of uploaded asset", %{token: token, user_token: user_token} do
    upload_file(token, @type_asset, @example_file)
    conn = fetch_file(user_token, "#{@type_asset}/#{@asset}")

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    
    assert conn.state == :chunked
    assert conn.status == 200

    assert File.exists?(path)
    assert conn.resp_body == File.read!(path)
  end


  test "failing unauthorised retrieval of uploaded asset", %{token: token} do
    upload_file(token, @type_asset, @example_file)
    conn = fetch_file(@bad_token, "#{@type_asset}/#{@asset}")

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(path)
  end


  defp upload_file(token, path, file) do
    upload = %{"file" => %Plug.Upload{path: file, filename: String.split(file, "/") |> List.last}}
    call_with_token(token, :put, "upload/#{path}", upload)
  end

  defp fetch_file(token, path) do
    call_with_token(token, :get, "fetch/#{path}")
  end

  defp call_with_token(token, type, path, params \\ %{}) when is_atom(type) and is_binary(token) and is_binary(path) do
    %{conn(type, "/api/v1/#{path}") | params: params}
    |> put_req_header("authorization", "Bearer " <> token)
    |> Router.call([])
  end
end