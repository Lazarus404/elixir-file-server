defmodule FileServer do
  use Application

  def start(_type, _args) do
    IO.puts "FileServer"
    FileServer.Supervisor.start_link
  end
end