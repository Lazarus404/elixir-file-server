defmodule FileServer.UploadAssets do
  use Arc.Definition
  # use Arc.Ecto.Definition

  @versions [:original]
  @acl :public_read

  # Whitelist file extensions:
  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png) |> Enum.member?(file.file_name |> String.downcase |> Path.extname)
  end

  def __storage, do: Arc.Storage.Local

  # Override the persisted filenames:
  def filename(_, {file, scope}) do
    case Map.has_key?(scope, :asset_type) && Map.get(scope, :asset_type) == "bg" do
      true ->
        file_extension = file.file_name |> Path.extname |> String.downcase
        "site_bg"
      _ ->
        [name|_] = String.split(file.file_name, ".")
        Zarex.sanitize(name |> String.downcase)
    end
  end

  # Override the storage directory:
  def storage_dir(_, {file, scope}) do
    root_path = Application.get_env(:file_server, :fs_path, "priv/static/assets/sites/").("asset")
    "#{root_path}#{scope.target}" # /#{scope.type}/#{scope.path}
  end
end
