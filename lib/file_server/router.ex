defmodule FileServer.Router do
  use FileServer.AuthProxyPlug
  use Plug.Router

  import Plug.Conn
  import FileServer.Utils.Parsers

  plug :parse_token
  plug Plug.Parsers, parsers: [:urlencoded, :json]
  plug :match
  plug Joken.Plug, verify: &FileServer.Utils.Parsers.verify_admin/0
  plug :dispatch

  alias FileServer.UploadFiles
  alias FileServer.UploadAssets
  alias FileServer.Utils.FileList

  @tertiary  ["primary", "secondary", "tertiary"]
  @secondary ["primary", "secondary"]
  @primary   ["primary"]

  @skip_token_verification %{joken_skip: true}
  @user_verification %{joken_verify: &FileServer.Utils.Parsers.verify_user/0}
  @admin_verification %{joken_verify: &FileServer.Utils.Parsers.verify_admin/0}
  @v1 "/api/v1"

  @chunk_size 128

  @doc """
  Handles private (admin/sys/uploader) file uploads from token host
  with fallback to Plug.Conn host.  If the parameter "CKEditorFuncNum"
  is passed, then this is a CKEditor upload and thus an HTML template
  is returned.
  """
  put "#{@v1}/upload/:type/*target" do
    host = get_host(conn)
    dir = join_path(target)
    with %{"file" => file} <- conn.params,
          {:ok, file} <- :erlang.apply(
                            (if type == "asset", do: UploadAssets, else: UploadFiles), 
                            :store, 
                            [{file, %{url: host, asset_type: "site-#{type}", target: join_path([host, dir])}}]) do
      if Map.has_key?(conn.params, "CKEditorFuncNum") do
        render(conn, 201, "uploaded.html", %{file: file, domain: "http://" <> host, func_num: conn.params["CKEditorFuncNum"]})
      else
        send_json(conn, 201, %{folder: dir, value: file, id: "#{type}:" <> join_path(dir, file), type: FileList.file_type(file), status: "server"})
      end
    else e ->
      send_json(conn, 401, %{error: e})
    end
  end

  @doc """
  Handles private asset requests from token host
  with fallback to Plug.Conn host
  """
  get "#{@v1}/fetch/asset/*source", private: @user_verification do
    source = join_path(source)
    with {:ok, file_path} <- build_path(conn, source, "asset"),
         :ok <- file_exists?(file_path) do
      download(conn, file_path, true)
    else {:error, e} ->
      conn
      |> send_json(404, %{error: "Could not retrieve file", message: e})
    end
  end

  @doc """
  Handles private file requests from token host
  with fallback to Plug.Conn host
  """
  get "#{@v1}/fetch/file/:level/*source", private: @user_verification do
    source = join_path(level, source)
    with {:ok, file_path} <- build_path(conn, source),
         :ok <- file_exists?(file_path) do
      download(conn, file_path, true)
    else {:error, e} ->
      conn
      |> send_json(404, %{error: "Could not retrieve file", message: e})
    end
  end

  @doc """
  Handles public assets requests to a given domain
  """
  get "#{@v1}/asset/*source", private: @skip_token_verification do
    source = join_path(source)
    with {:ok, file_path} <- build_path(conn, source, "asset"),
         :ok <- file_exists?(file_path) do
      download(conn, file_path)
    else {:error, e} ->
      conn
      |> send_json(404, %{error: "Could not retrieve file", message: e})
    end
  end

  @doc """
  Returns a valid CKEditor File Browser page
  """
  get "#{@v1}/browse", private: @skip_token_verification do
    %{"CKEditorFuncNum" => func_num} = conn.params
    host = get_host(conn)
    render(conn, 200, "filebrowser.html", %{host: host, domain: "http://" <> host, func_num: conn.params["CKEditorFuncNum"]})
  end

  @doc """
  Removes a file as specified in the 'source' parameter, which can be a comma
  delimited string of paths. Only admin, sys and uploader can remove a file.
  """
  delete "#{@v1}/remove", private: @admin_verification do
    %{"source" => source} = conn.params
    sources = String.split(source, ",")
    try do
      Enum.map(sources, fn (src) ->
        with {type, file} <- get_filename(src),
             {:ok, src_path} <- build_path(conn, file, type) do
          File.rm_rf!(src_path)
        end
      end)
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, "[\"ok\"]")
    rescue
      e ->
        send_json(conn, 422, %{error: "Could not remove item(s)", message: e})
    end
  end

  @doc """
  Removes a specific file as specified in the path. 
  Only admin, sys and uploader can remove a file.
  :type can be 'asset' or 'file'
  """
  delete "#{@v1}/remove/:type/*source", private: @admin_verification do
    source = join_path(source)
    with {:ok, src_path} <- build_path(conn, source, type),
         true <- File.exists?(src_path),
         {:ok, _} <- File.rm_rf(src_path) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, "[\"ok\"]")
    else e ->
      send_json(conn, 422, %{error: "Could not remove item", message: e})
    end
  end

  @doc """
  Renames a specific file as specified in the path using the 'target' 
  value specified in the params.  Only admin, sys and uploader can rename a file.
  :type can be 'asset' or 'file'
  """
  post "#{@v1}/rename/:type/*source" do
    source = join_path(source)
    with %{"target" => target} <- conn.params,
         {:ok, src_path} <- build_path(conn, source, type),
         {:ok, trg_path} <- new_path(src_path, target),
         :ok <- File.rename(src_path, trg_path) do
      send_json(conn, 200, %{id: "#{Path.dirname(src_path)}/#{target}", value: target})
    else {:error, e} ->
      send_json(conn, 422, %{error: "Could not rename item", message: e})
    end
  end

  @doc """
  Copies a specific file as specified in the path to the 'target' 
  value specified in the params.  Only admin, sys and uploader can copy a file.
  :type can be 'asset' or 'file'
  """
  post "#{@v1}/copy/:type/*source" do
    source = join_path(source)
    with %{"target" => target} <- conn.params,
         {:ok, spath} <- build_path(conn, source, type),
         {ttype, trg} <- get_filename(target),
         {:ok, tpath} <- build_path(conn, trg, ttype),
         :ok <- make_path(tpath) do
     file_name = Path.basename(spath)
     {:ok, _} = File.copy(spath, "#{tpath}/#{file_name}")
      send_json(conn, 200, %{id: "#{target}/#{file_name}", value: file_name})
    else {:error, e} ->
      send_json(conn, 422, %{error: "Could not copy item", message: e})
    end
  end

  @doc """
  Copies a one or more files as specified in the 'source' param to the 'target' param.
  The source file may be a comma delimited list of paths.  Only admin, sys and uploader 
  can copy a file.
  :type can be 'asset' or 'file'
  """
  post "#{@v1}/copy" do
    %{"source" => source, "target" => target} = conn.params
    sources = String.split(source, ",")
    try do
      complete = Enum.map(sources, fn (s) ->
        with {stype, src} <- get_filename(s),
             {ttype, trg} <- get_filename(target),
             {:ok, spath} <- build_path(conn, src, stype),
             {:ok, tpath} <- build_path(conn, trg, ttype),
             :ok <- make_path(tpath) do
          file_name = Path.basename(src)
          File.copy!(spath, "#{tpath}/#{file_name}")
          %{id: "#{target}/#{file_name}", value: file_name}
        end
      end)
      send_json(conn, 200, complete)
    rescue e ->
        send_json(conn, 422, %{error: "Could not copy item(s)", message: e})
    end
  end

  @doc """
  Moves a specific file as specified in the path to the 'target' 
  value specified in the params.  Only admin, sys and uploader can move a file.
  :type can be 'asset' or 'file'
  """
  post "#{@v1}/move/:type/*source" do
    source = join_path(source)
    with %{"target" => target} <- conn.params,
         {:ok, spath} <- build_path(conn, source, type),
         {ttype, trg} <- get_filename(target),
         {:ok, tpath} <- build_path(conn, trg, ttype),
         :ok <- make_path(tpath) do
      file_name = Path.basename(spath)
      File.rename(spath, "#{tpath}/#{file_name}")
      send_json(conn, 200, %{id: "#{target}/#{file_name}", value: file_name})
    else {:error, e} ->
      send_json(conn, 422, %{error: "Could not move item", message: e})
    end
  end

  @doc """
  Moves a one or more files as specified in the 'source' param to the 'target' param.
  The source file may be a comma delimited list of paths.  Only admin, sys and uploader 
  can move a file.
  :type can be 'asset' or 'file'
  """
  post "#{@v1}/move" do
    %{"source" => source, "target" => target} = conn.params
    sources = String.split(source, ",")
    try do
      complete = Enum.map(sources, fn (s) ->
        with {stype, src} <- get_filename(s),
             {ttype, trg} <- get_filename(target),
             {:ok, spath} <- build_path(conn, src, stype),
             {:ok, tpath} <- build_path(conn, trg, ttype),
             :ok <- make_path(tpath) do
          file_name = Path.basename(src)
          File.rename(spath, "#{tpath}/#{file_name}")
          %{id: "#{target}/#{file_name}", value: file_name}
        end
      end)
      send_json(conn, 200, complete)
    rescue e ->
      send_json(conn, 422, %{error: "Could not move item(s)", message: e})
    end
  end

  @doc """
  Creates a directory at the specified source. :type may be 'asset' or
  'file'. If specifying a nested directory, all directories prior which
  do not yet exist will also be created.
  """
  put "#{@v1}/mkdir/:type/*source" do
    source = join_path(source)
    with {:ok, spath} <- build_path(conn, source, type),
         :ok <- File.mkdir_p(spath) do
      send_json(conn, 201, %{id: "#{type}/#{source}", value: source})
    else e ->
      send_json(conn, 422, %{error: "Could not create directory", message: e})
    end
  end

  @doc """
  Returns a list of all assets and files as a list for a given host.
  """
  get "#{@v1}/ls", private: @skip_token_verification do
    with {:ok, fpath} <- build_path(conn, "", "file"),
         {:ok, apath} <- build_path(conn, "", "asset"),
         folders when is_list(folders) <- ls(conn, fpath, @tertiary, "file"),
         assets when is_list(assets) <- ls(conn, apath, "", "asset") do
      send_json(conn, 200, FileList.wrap(List.flatten(folders, assets)))
    else e ->
      send_json(conn, 422, %{error: "Could not list directory", message: e})
    end
  end

  match _, private: @skip_token_verification do
    send_resp(conn, 404, "oops")
  end

  def parse_token(conn, _) do
    with [<<"Bearer ", auth::binary>>] <- Plug.Conn.get_req_header(conn, "authorization"),
         %{"email" => email, "role" => role, "host" => host} <- verify_token(auth).claims do
      Plug.Conn.assign(conn, :auth, %{email: email, role: role, host: host})
    else _ ->
      conn
    end
  end

  def get_path(type \\ "file"), do: Application.get_env(:file_server, :fs_path).(type)

  def get_template_path, do: Application.get_env(:file_server, :template_path)

  # -------------------------------
  # Private functions
  # -------------------------------

  defp render(conn, status, template, params \\ %{}) do
    with {:ok, tmpl} <- File.read(Path.join(get_template_path, template)),
         {:ok, map} <- parse_bb_params(params),
         page when is_binary(page) <- :bbmustache.render(tmpl, map) do
      send_resp(conn, status, page)
    end
  end

  defp parse_bb_params(%{} = params), do: {:ok, Enum.map(params, fn {k, v} -> {String.to_char_list("#{k}"), v} end)}

  defp put_file_header(conn, path, stat) do
    conn
    |> put_resp_content_type(:mimerl.filename(path))
    |> put_resp_header("content-length", "#{stat.size}")
    |> put_resp_header("content-disposition", "attachment; filename=#{Path.basename(path)}")
    |> put_resp_header("content-transfer-encoding", "binary")
    |> put_resp_header("cache-control", "must-revalidate, post-check=0, pre-check=0")
  end

  defp list_folders(4), do: @tertiary
  defp list_folders(2), do: @secondary
  defp list_folders(1), do: @primary
  defp list_folders(_), do: []


  defp ls(conn, path, dir \\ "", type \\ "file")
  defp ls(conn, path, dir, type) when is_list(dir) do
    Enum.map(dir, fn (t) -> ls(conn, path, t, type) end)
  end
  defp ls(conn, path, dir, type) do
    FileList.tree!(path, Path.join([get_host(conn), dir]), "#{type}/", dir)
  end

  defp get_host(conn) do
    case user_data(conn) do
      %{host: host} ->
        host
      _ ->
        String.split(conn.host, ".") |> List.first
    end
  end

  defp join_path([]) do
    ""
  end
  defp join_path(items) when is_list(items) do
    Path.join(List.flatten(items))
  end
  defp join_path(items) when is_binary(items) do
    items
  end
  defp join_path(item1, item2) do
    join_path([item1, item2])
  end

  defp build_path(%Plug.Conn{} = conn, path, type \\ "file") when is_binary(path) and is_binary(type) do
    {:ok, Path.join([
      get_path(type), # path 
      get_host(conn), # domain 
      path # file
    ])}
  end

  defp new_path(src_path, target) when is_binary(src_path) and is_binary(target) do
    {:ok, "#{Path.dirname(src_path)}/#{target}"}
  end

  defp make_path(path) when is_binary(path) do
    if not File.exists?(path) do
      File.mkdir_p(path)
    end
    :ok
  end

  defp get_filename(path) do
    parts = String.split(path, "/")
    {List.first(parts), join_path(List.last(parts))}
  end

  defp get_file(path) do
    case File.read(path) do
      {:ok, file_content} ->
        stat = File.stat!(path, time: :posix)
        {:ok, file_content, stat}
      {:error, e} ->
        {:error, e}
    end
  end

  defp file_exists?(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "File or directory does not exist"}
    end
  end

  defp download(conn, path, as_download \\ false) do
    if File.dir?(path) do
      conn = conn
      |> put_resp_content_type(Plug.MIME.type("zip"))
      |> send_chunked(200)

      chunk_file = fn d ->
       {:ok, conn} = chunk(conn, d)
      end

      Zipflow.Stream.init
      |> Zipflow.OS.dir_entry(chunk_file, path, [rename: &Path.relative_to(&1, path)])
      |> Zipflow.Stream.flush(chunk_file)
      conn
    else
      stat = File.stat!(path, time: :posix)
      
      if as_download, do:
        conn = conn |> put_resp_header("content-disposition", "attachment; filename=#{Path.basename(path)}")

      conn = conn
      |> put_resp_content_type(:mimerl.filename(path))
      |> put_resp_header("content-length", "#{stat.size}")
      |> put_resp_header("content-transfer-encoding", "binary")
      |> put_resp_header("cache-control", "must-revalidate, post-check=0, pre-check=0")
      |> send_chunked(200)

      File.stream!(path, [], @chunk_size)
      |> Enum.into(conn)
    end
  end

  defp user_data(conn) do
    case conn.assigns do
      %{auth: auth} -> auth
      _ -> %{}
    end
  end
end