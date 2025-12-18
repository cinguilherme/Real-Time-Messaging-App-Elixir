defmodule MessagingCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Load and validate feature configuration
    config = load_and_validate_config!()

    # Configure adapters based on feature flags
    configure_adapters(config)

    # Build dynamic children based on configuration
    children = build_children(config)

    # Log boot summary
    Messaging.Config.Logger.log_boot_summary(config)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MessagingCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Private functions

  defp load_and_validate_config! do
    Messaging.Config.Loader.load!()
  end

  defp configure_adapters(config) do
    # Configure receipts adapter
    receipts_adapter =
      if config.features.receipts do
        case config.storage.receipts do
          :postgres -> Messaging.Adapters.Receipts.Postgres
          :none -> Messaging.Adapters.Receipts.Noop
        end
      else
        Messaging.Adapters.Receipts.Noop
      end

    Application.put_env(:messaging_core, :receipts_adapter, receipts_adapter)

    # Configure inbox adapter
    inbox_adapter =
      if config.features.inbox do
        case config.storage.inbox do
          :postgres -> Messaging.Adapters.Inbox.Postgres
          :redis -> Messaging.Adapters.Inbox.Postgres  # Redis adapter not implemented yet
          :none -> Messaging.Adapters.Inbox.Noop
        end
      else
        Messaging.Adapters.Inbox.Noop
      end

    Application.put_env(:messaging_core, :inbox_adapter, inbox_adapter)

    # Configure history adapter
    history_adapter =
      if config.storage.history == :postgres do
        Messaging.Adapters.History.Postgres
      else
        Messaging.Adapters.History.Noop
      end

    Application.put_env(:messaging_core, :history_adapter, history_adapter)

    # Configure blobs adapter
    blobs_adapter =
      if config.features.media or config.features.file_ops do
        case config.storage.blobs do
          :s3 -> Messaging.Adapters.Blobs.S3
          :local -> Messaging.Adapters.Blobs.Local
          :none -> Messaging.Adapters.Blobs.Noop
        end
      else
        Messaging.Adapters.Blobs.Noop
      end

    Application.put_env(:messaging_core, :blobs_adapter, blobs_adapter)

    :ok
  end

  defp build_children(config) do
    [
      # Always start Repo if any postgres storage is used
      if(uses_postgres?(config), do: Messaging.Repo)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp uses_postgres?(config) do
    config.storage
    |> Map.values()
    |> Enum.any?(&(&1 == :postgres))
  end
end
