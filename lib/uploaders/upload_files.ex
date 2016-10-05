defmodule FileServer.UploadFiles do
  use Arc.Definition
  # use Arc.Ecto.Definition

  @versions [:original]
  @acl :public_read

  # Whitelist file extensions:
  def validate({file, _}) do
    ~w(.jpg .jpeg .png .gif .bmp .psd .tif .html .htm .txt .docx .doc .zip .pdf .ppt .pptx .xls .xlsx .xlsm) |> Enum.member?(file.file_name |> String.downcase |> Path.extname)
  end

  def __storage, do: Arc.Storage.Local

  # Override the persisted filenames:
  def filename(_, {file, scope}) do
    [name|_] = String.split(file.file_name, ".")
    Zarex.sanitize(name |> String.downcase)
  end

  def transform(:original, {file, scope} = params) do
    if ~w(.jpg .jpeg .png .gif .bmp) |> Enum.member?(file.file_name |> String.downcase |> Path.extname) do
      {:convert, "-resize 960x2000\>"}
    else
      :noaction
    end
  end

  # Override the storage directory:
  def storage_dir(_, {file, scope}) do
    root_path = Application.get_env(:file_server, :fs_path, "priv/static/files/sites/").("file")
    "#{root_path}#{scope.target}" # /#{scope.type}/#{scope.path}
  end
end
