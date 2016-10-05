defmodule CopyTest do
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
  # File copying functionality
  # -------------------------------


  test "copy uploaded asset", %{token: token} do
    upload_file(token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    assert File.exists?(path)
    asset = File.read!(path)

    conn = copy_file(token, "#{@type_asset}/#{@asset}", %{
      "target" => "#{@type_asset}/#{@new_path}"
    })

    path_new = Path.join([Router.get_path(@type_asset), @host, "#{@new_path}/#{@asset}"])

    assert Poison.decode!(conn.resp_body) == %{"value" => @asset, "id" => "#{@type_asset}/#{@new_path}/#{@asset}"}
    assert conn.state == :sent
    assert conn.status == 200

    assert File.exists?(path)
    assert File.exists?(path_new)
    assert File.read!(path_new) == asset
  end


  test "failing unauthorised copying of uploaded asset", %{token: token, user_token: user_token} do
    upload_file(token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    assert File.exists?(path)

    path_new = Path.join([Router.get_path(@type_asset), @host, "#{@new_path}/#{@asset}"])

    conn = copy_file(@bad_token, "#{@type_asset}/#{@asset}", %{
      "target" => "#{@type_asset}/#{@new_path}"
    })

    assert conn.state == :sent
    assert conn.status == 401

    assert File.exists?(path)
    refute File.exists?(path_new)

    conn = copy_file(user_token, "#{@type_asset}/#{@asset}", %{
      "target" => "#{@type_asset}/#{@new_path}"
    })

    assert conn.state == :sent
    assert conn.status == 401

    assert File.exists?(path)
    refute File.exists?(path_new)
  end


  test "copy uploaded file", %{token: token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    assert File.exists?(path)
    asset = File.read!(path)

    conn = copy_file(token, "#{@type_file}/#{@path}/#{@asset}", %{
      "target" => "#{@type_file}/#{@new_path}"
    })

    path_new = Path.join([Router.get_path(@type_file), @host, "#{@new_path}/#{@asset}"])

    assert Poison.decode!(conn.resp_body) == %{"value" => @asset, "id" => "#{@type_file}/#{@new_path}/#{@asset}"}
    assert conn.state == :sent
    assert conn.status == 200

    assert File.exists?(path)
    assert File.exists?(path_new)
    assert File.read!(path_new) == asset
  end


  test "failing unauthorised copying of uploaded file", %{token: token, user_token: user_token} do
    upload_file(token, Path.join(@type_file, @path), @example_file)

    path = Path.join([Router.get_path(@type_file), @host, "#{@path}/#{@asset}"])
    assert File.exists?(path)

    path_new = Path.join([Router.get_path(@type_file), @host, "#{@new_path}/#{@asset}"])

    conn = copy_file(@bad_token, "#{@type_file}/#{@path}/#{@asset}", %{
      "target" => "#{@type_file}/#{@new_path}"
    })

    assert conn.state == :sent
    assert conn.status == 401

    assert File.exists?(path)
    refute File.exists?(path_new)

    conn = copy_file(user_token, "#{@type_file}/#{@path}/#{@asset}", %{
      "target" => "#{@type_file}/#{@new_path}"
    })

    assert conn.state == :sent
    assert conn.status == 401

    assert File.exists?(path)
    refute File.exists?(path_new)
  end


  test "copy uploaded asset to file directory", %{token: token} do
    upload_file(token, @type_asset, @example_file)

    path = Path.join([Router.get_path(@type_asset), @host, "#{@asset}"])
    assert File.exists?(path)
    asset = File.read!(path)

    conn = copy_file(token, "#{@type_asset}/#{@asset}", %{
      "target" => "#{@type_file}/#{@new_path}"
    })

    path_new = Path.join([Router.get_path(@type_file), @host, "#{@new_path}/#{@asset}"])

    assert Poison.decode!(conn.resp_body) == %{"value" => @asset, "id" => "#{@type_file}/#{@new_path}/#{@asset}"}
    assert conn.state == :sent
    assert conn.status == 200

    assert File.exists?(path)
    assert File.exists?(path_new)
    assert File.read!(path_new) == asset
  end


  test "copy multiple uploaded assets", %{token: token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join([Router.get_path(@type_asset), @host])

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))

    asset = File.read!(Path.join([path, "#{@asset}"]))
    asset2 = File.read!(Path.join([path, "#{@asset_other}"]))

    conn = copy_file(token, "", %{
      "target" => "#{@type_asset}/#{@new_path}",
      "source" => "#{@type_asset}/#{@asset},#{@type_asset}/#{@asset_other}"
    })

    path_new = Path.join([Router.get_path(@type_asset), @host, "#{@new_path}"])

    assert Poison.decode!(conn.resp_body) == [
      %{"value" => @asset, "id" => "#{@type_asset}/#{@new_path}/#{@asset}"},
      %{"value" => @asset_other, "id" => "#{@type_asset}/#{@new_path}/#{@asset_other}"}
    ]
    assert conn.state == :sent
    assert conn.status == 200

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))
    assert File.exists?(Path.join(path_new, @asset))
    assert File.exists?(Path.join(path_new, @asset_other))
    asset_new = File.read!(Path.join([path_new, "#{@asset}"]))
    asset_new2 = File.read!(Path.join([path_new, "#{@asset_other}"]))
    assert asset_new == asset
    assert asset_new2 == asset2
  end


  test "failing unauthorised copying of multiple uploaded assets", %{token: token, user_token: user_token} do
    upload_file(token, @type_asset, @example_file)
    upload_file(token, @type_asset, @example_file_other)

    path = Path.join([Router.get_path(@type_asset), @host])

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))

    path_new = Path.join([Router.get_path(@type_asset), @host, "#{@new_path}"])

    conn = copy_file(@bad_token, "", %{
      "target" => "#{@type_asset}/#{@new_path}",
      "source" => "#{@type_asset}/#{@asset},#{@type_asset}/#{@asset_other}"
    })

    assert conn.state == :sent
    assert conn.status == 401

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))
    refute File.exists?(Path.join(path_new, @asset))
    refute File.exists?(Path.join(path_new, @asset_other))

    conn = copy_file(user_token, "", %{
      "target" => "#{@type_asset}/#{@new_path}",
      "source" => "#{@type_asset}/#{@asset},#{@type_asset}/#{@asset_other}"
    })

    assert conn.state == :sent
    assert conn.status == 401

    assert File.exists?(Path.join(path, @asset))
    assert File.exists?(Path.join(path, @asset_other))
    refute File.exists?(Path.join(path_new, @asset))
    refute File.exists?(Path.join(path_new, @asset_other))
  end


  defp upload_file(token, path, file) do
    upload = %{"file" => %Plug.Upload{path: file, filename: String.split(file, "/") |> List.last}}
    call_with_token(token, :put, "upload/#{path}", upload)
  end

  defp copy_file(token, path, params \\ %{}) do
    call_with_token(token, :post, "copy/#{path}", params)
  end

  defp call_with_token(token, type, path, params \\ %{}) when is_atom(type) and is_binary(token) and is_binary(path) do
    %{conn(type, "/api/v1/#{path}") | params: params}
    |> put_req_header("authorization", "Bearer " <> token)
    |> Router.call([])
  end
end