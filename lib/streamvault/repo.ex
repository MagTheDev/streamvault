defmodule Streamvault.Repo do
  use Ecto.Repo,
    otp_app: :streamvault,
    adapter: Ecto.Adapters.SQLite3
end
