defmodule LSTest do
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
  @asset_other "example2.png"
  
  @example_file "test/fixtures/#{@asset}"
  @example_file_other "test/fixtures/#{@asset_other}"

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


  # -------------------------------
  # Directory listing functionality
  # -------------------------------


  test "list directory contents", %{token: token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join([Router.get_path(@type_asset), @host])

    conn = ls(token, "")

    assert conn.state == :sent
    assert conn.status == 200
  end


  test "list directory contents as user", %{token: token, user_token: user_token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join([Router.get_path(@type_asset), @host])

    conn = ls(user_token, "")

    assert conn.state == :sent
    assert conn.status == 200
  end


  test "list directory contents when unauthenticated", %{token: token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join([Router.get_path(@type_asset), @host])

    conn = ls(@bad_token, "")

    assert conn.state == :sent
    assert conn.status == 200
  end


  defp upload_file(token, path, file) do
    upload = %{"file" => %Plug.Upload{path: file, filename: String.split(file, "/") |> List.last}}
    call_with_token(token, :put, "upload/#{path}", upload)
  end

  defp ls(token, path, params \\ %{}) do
    call_with_token(token, :get, "ls/#{path}", params)
  end

  defp call_with_token(token, type, path, params \\ %{}) when is_atom(type) and is_binary(token) and is_binary(path) do
    %{conn(type, "/api/v1/#{path}") | params: params}
    |> put_req_header("authorization", "Bearer " <> token)
    |> Router.call([])
  end
end