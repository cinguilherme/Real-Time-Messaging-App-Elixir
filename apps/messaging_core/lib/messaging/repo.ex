defmodule Messaging.Repo do
  use Ecto.Repo,
    otp_app: :messaging_core,
    adapter: Ecto.Adapters.Postgres
end
