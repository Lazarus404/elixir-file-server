defmodule FileServer.Utils.FileList do
  def tree!(path, url_path, id_prepend \\ "", value \\ "assets", id_append \\ "") do
    root = Path.join(path, url_path)
    if not File.exists?(root), do: File.mkdir_p!(root)
    stat = File.stat!(root, time: :posix)
    [%{id: id_prepend <> url_path <> id_append, size: stat.size, date: stat.ctime, type: "folder", value: value, data: parse_files(root, url_path <> id_append, id_prepend), open: true}]
  end
  def tree(path, url_path, id_prepend \\ "", value \\ "assets", id_append \\ "") do
    try do
      {:ok, tree!(path, url_path, id_prepend, value, id_append)}
    rescue
      e -> {:error, e}
    end
  end

  def wrap(file_list) do
    [%{id: "site_files", type: "folder", value: "site_files", data: file_list, open: true}]
  end

  def parse_files(dir, url_path, id_prepend) do
    dirs = for file <- File.ls!(dir),
      File.dir?(Path.join(dir, file)),
      stat = File.stat!(Path.join(dir, file), time: :posix) do
        id = id_prepend <> Path.join("#{url_path}", file)
        %{id: id, size: stat.size, date: stat.ctime, type: "folder", data: parse_files(Path.join(dir, file), Path.join(url_path, file), id_prepend), value: file, open: true}
      end
    files = for file <- File.ls!(dir),
      !File.dir?(Path.join(dir, file)),
      stat = File.stat!(Path.join(dir, file), time: :posix) do
        id = id_prepend <> Path.join("#{url_path}", file)
        %{id: id, size: stat.size, date: stat.ctime, type: file_type(file), value: file}
      end
    dirs ++ files
  end

  def file_type(file) do
    ext = case Path.extname(file) do
      "" -> file
      <<".", x::binary>> -> x
      x -> x
    end
    type(String.downcase(ext))
  end

  defp type("doc"), do: "Word"
  defp type("docx"), do: "Word"
  defp type("xsl"), do: "Excel"
  defp type("xlsx"), do: "Excel"
  defp type("aif"), do: "Audio"
  defp type("aiff"), do: "Audio"
  defp type("avi"), do: "Video"
  defp type("cvs"), do: "Canvas"
  defp type("dbf"), do: "DBase"
  defp type("eps"), do: "PostScript"
  defp type("exe"), do: "Windows App"
  defp type("htm"), do: "Web page"
  defp type("html"), do: "Web page"
  defp type("jpg"), do: "JPEG Image"
  defp type("jpeg"), do: "JPEG Image"
  defp type("gif"), do: "GIF Image"
  defp type("png"), do: "PNG Image"
  defp type("bmp"), do: "Bitmap Image"
  defp type("mdb"), do: "MS Access"
  defp type("mid"), do: "MIDI Sound"
  defp type("midi"), do: "MIDI Sound"
  defp type("mov"), do: "QuickTime Video"
  defp type("pdf"), do: "Adobe PDF"
  defp type("ppt"), do: "PowerPoint"
  defp type("psd"), do: "PhotoShop Image"
  defp type("psp"), do: "PaintShop Image"
  defp type("rtf"), do: "Rich Text Format"
  defp type("tar"), do: "Unix Archive"
  defp type("txt"), do: "Simple Text File"
  defp type("wav"), do: "Windows Audio"
  defp type("mp3"), do: "MPeg Audio"
  defp type("vcf"), do: "V-Card"
  defp type("zip"), do: "Archive (Compressed)"
  defp type(f), do: String.upcase(f)
end