defmodule MessagingApi.HealthController do
  use Phoenix.Controller, formats: [:json]

  def check(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end
end
