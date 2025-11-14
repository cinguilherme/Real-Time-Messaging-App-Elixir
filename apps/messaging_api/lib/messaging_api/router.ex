defmodule MessagingApi.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MessagingApi do
    pipe_through :api

    get "/healthz", HealthController, :check
  end

  scope "/v1", MessagingApi do
    pipe_through :api

    post "/messages", MessageController, :create
    get "/conversations/:conversation_id/messages", MessageController, :list
    post "/messages/:id/read", MessageController, :mark_read
    post "/messages/:id/deliver", MessageController, :mark_delivered
  end
end
