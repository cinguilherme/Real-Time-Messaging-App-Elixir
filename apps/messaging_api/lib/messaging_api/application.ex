defmodule MessagingApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Load feature configuration (already validated by MessagingCore.Application)
    config = Messaging.Config.Loader.load!()

    children = build_children(config)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MessagingApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp build_children(config) do
    [
      # PubSub only if enabled
      if config.features.pubsub do
        {Phoenix.PubSub, name: MessagingApi.PubSub}
      end,
      # Always start Telemetry
      MessagingApi.Telemetry,
      # Always start the Endpoint
      MessagingApi.Endpoint
    ]
    |> Enum.reject(&is_nil/1)
  end
end
