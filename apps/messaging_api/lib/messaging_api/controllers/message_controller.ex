defmodule MessagingApi.MessageController do
  use Phoenix.Controller, formats: [:json]

  def create(conn, _params) do
    # Implementation will be added later
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "Not implemented yet"})
  end

  def mark_read(conn, _params) do
    # Implementation will be added later
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "Not implemented yet"})
  end
end
