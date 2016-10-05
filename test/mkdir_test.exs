defmodule MKDirTest do
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
  @new_path "secondary"

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
  # Directory creation functionality
  # -------------------------------


  test "create new directory", %{token: token} do
    path = Path.join([Router.get_path(@type_asset), @host])

    refute File.exists?(Path.join(path, @new_path))

    conn = mkdir(token, "#{@type_asset}/#{@new_path}")

    assert conn.state == :sent
    assert conn.status == 201
    assert File.exists?(Path.join(path, @new_path))
  end


  test "failing unauthorised creation of new directory", %{token: token, user_token: user_token} do
    path = Path.join([Router.get_path(@type_asset), @host])

    refute File.exists?(Path.join(path, @new_path))

    conn = mkdir(@bad_token, "#{@type_asset}/#{@new_path}")

    assert conn.state == :sent
    assert conn.status == 401
    refute File.exists?(Path.join(path, @new_path))

    conn = mkdir(user_token, "#{@type_asset}/#{@new_path}")

    assert conn.state == :sent
    assert conn.status == 401
    refute File.exists?(Path.join(path, @new_path))
  end


  defp upload_file(token, path, file) do
    upload = %{"file" => %Plug.Upload{path: file, filename: String.split(file, "/") |> List.last}}
    call_with_token(token, :put, "upload/#{path}", upload)
  end

  defp mkdir(token, path, params \\ %{}) do
    call_with_token(token, :put, "mkdir/#{path}", params)
  end

  defp call_with_token(token, type, path, params \\ %{}) when is_atom(type) and is_binary(token) and is_binary(path) do
    %{conn(type, "/api/v1/#{path}") | params: params}
    |> put_req_header("authorization", "Bearer " <> token)
    |> Router.call([])
  end
end