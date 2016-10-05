# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :file_server,
  http_port: 4001,
  fs_path: fn type -> "priv/static/#{type}s/sites/" end,
  certs_path: "../certificates",
  certs_private_key: "private.key",
  certs_public_key: "public.key"