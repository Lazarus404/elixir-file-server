defmodule UploadTest do
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


  # -------------------------------
  # Uploading functionality
  # -------------------------------


  test "upload file to host directory", %{token: token} do
    conn = upload_file(token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 201
    assert File.exists?(path)
  end


  test "failing unauthorised upload file to host directory", %{user_token: user_token} do
    conn = upload_file(@bad_token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 401
    refute File.exists?(path)

    conn = upload_file(user_token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 401
    refute File.exists?(path)
  end


  test "upload asset to host directory", %{token: token} do
    conn = upload_file(token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 201
    assert File.exists?(path)
  end


  test "failing unauthorised upload asset to host directory", %{user_token: user_token} do
    conn = upload_file(@bad_token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 401
    refute File.exists?(path)

    conn = upload_file(user_token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    
    assert conn.state == :sent
    assert conn.status == 401
    refute File.exists?(path)
  end


  defp upload_file(token, path, file) do
    upload = %{"file" => %Plug.Upload{path: file, filename: String.split(file, "/") |> List.last}}
    call_with_token(token, :put, "upload/#{path}", upload)
  end

  defp call_with_token(token, type, path, params \\ %{}) when is_atom(type) and is_binary(token) and is_binary(path) do
    %{conn(type, "/api/v1/#{path}") | params: params}
    |> put_req_header("authorization", "Bearer " <> token)
    |> Router.call([])
  end
end