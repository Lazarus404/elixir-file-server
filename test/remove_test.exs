defmodule RemoveTest do
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
  # File removal functionality
  # -------------------------------


  test "remove uploaded file", %{token: token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])

    assert File.exists?(path)

    conn = delete_file(token, "#{@type_file}/#{@path}/#{@asset}")

    assert conn.state == :sent
    assert conn.status == 200
    refute File.exists?(path)
  end


  test "failing unauthorised removal of uploaded file", %{token: token, user_token: user_token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])

    assert File.exists?(path)

    conn = delete_file(@bad_token, "#{@type_file}/#{@path}/#{@asset}")

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(path)

    conn = delete_file(user_token, "#{@type_file}/#{@path}/#{@asset}")

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(path)
  end


  test "remove uploaded asset", %{token: token} do
    upload_file(token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])

    assert File.exists?(path)

    conn = delete_file(token, "#{@type_asset}/#{@asset}")

    assert conn.state == :sent
    assert conn.status == 200
    refute File.exists?(path)
  end


  test "failing unauthorised removal of uploaded asset", %{token: token, user_token: user_token} do
    upload_file(token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])

    assert File.exists?(path)

    conn = delete_file(user_token, "#{@type_asset}/#{@asset}")

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(path)

    conn = delete_file(@bad_token, "#{@type_asset}/#{@asset}")

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(path)
  end


  test "remove multiple uploaded files", %{token: token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)
    upload_file(token, Path.join(@type_file, @path), @example_file_other)

    path = Path.join(Router.get_path(@type_file), @host)

    assert File.exists?(Path.join(path, "#{@path}/#{@asset}"))
    assert File.exists?(Path.join(path, "#{@path}/#{@asset_other}"))

    params = %{"source" => "#{@type_file}/#{@path}/#{@asset},#{@type_file}/#{@path}/#{@asset_other}"}
    conn = delete_file(token, "", params)

    assert conn.resp_body == "[\"ok\"]"
    assert conn.state == :sent
    assert conn.status == 200
    refute File.exists?(Path.join(path, @asset))
    refute File.exists?(Path.join(path, @asset_other))
  end


  test "failing unauthorised removal of multiple uploaded files", %{token: token, user_token: user_token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)
    upload_file(token, Path.join(@type_file, @path), @example_file_other)

    path = Path.join(Router.get_path(@type_file), @host)

    assert File.exists?(Path.join(path, "#{@path}/#{@asset}"))
    assert File.exists?(Path.join(path, "#{@path}/#{@asset_other}"))

    params = %{"source" => "#{@type_file}/#{@path}/#{@asset},#{@type_file}/#{@path}/#{@asset_other}"}

    conn = delete_file(user_token, "", params)

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(Path.join(path, "#{@path}/#{@asset}"))
    assert File.exists?(Path.join(path, "#{@path}/#{@asset_other}"))

    conn = delete_file(@bad_token, "", params)

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(Path.join(path, "#{@path}/#{@asset}"))
    assert File.exists?(Path.join(path, "#{@path}/#{@asset_other}"))
  end


  test "remove multiple uploaded assets", %{token: token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join(Router.get_path(@type_asset), @host)

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))

    params = %{"source" => "#{@type_asset}/#{@asset},#{@type_asset}/#{@asset_other}"}
    conn = delete_file(token, "", params)

    assert conn.resp_body == "[\"ok\"]"
    assert conn.state == :sent
    assert conn.status == 200
    refute File.exists?(Path.join(path, @asset))
    refute File.exists?(Path.join(path, @asset_other))
  end


  test "failing unauthorised remove of multiple uploaded assets", %{token: token, user_token: user_token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join(Router.get_path(@type_asset), @host)

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))

    params = %{"source" => "#{@type_asset}/#{@asset},#{@type_asset}/#{@asset_other}"}

    conn = delete_file(user_token, "", params)

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))

    conn = delete_file(@bad_token, "", params)

    assert conn.state == :sent
    assert conn.status == 401
    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))
  end


  defp upload_file(token, path, file) do
    upload = %{"file" => %Plug.Upload{path: file, filename: String.split(file, "/") |> List.last}}
    call_with_token(token, :put, "upload/#{path}", upload)
  end

  defp delete_file(token, path, params \\ %{}) do
    call_with_token(token, :delete, "remove/#{path}", params)
  end

  defp call_with_token(token, type, path, params \\ %{}) when is_atom(type) and is_binary(token) and is_binary(path) do
    %{conn(type, "/api/v1/#{path}") | params: params}
    |> put_req_header("authorization", "Bearer " <> token)
    |> Router.call([])
  end
end