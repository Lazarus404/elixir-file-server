defmodule FileServer.Worker do

  @http_port Application.get_env(:file_server, :http_port)

  def start_link do
    Plug.Adapters.Cowboy.http(FileServer.Router, [], port: @http_port)
    Plug.Adapters.Cowboy.http(FileServer.TestRouter, [], port: 4002)
  end

end