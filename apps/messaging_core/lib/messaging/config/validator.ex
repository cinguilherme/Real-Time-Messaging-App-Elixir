defmodule Messaging.Config.Validator do
  @moduledoc """
  Validates feature configuration rules and dependencies.
  Fails fast at boot with clear error messages.
  """

  alias Messaging.Config

  @doc """
  Validates the configuration and returns it if valid.
  Raises with detailed error messages if validation fails.
  """
  @spec validate!(Config.t()) :: Config.t()
  def validate!(%Config{} = config) do
    case validate(config) do
      {:ok, config} ->
        config

      {:error, errors} ->
        error_message = format_errors(errors)

        raise """
        Feature configuration validation failed:

        #{error_message}

        Please check your configuration file and fix the errors above.
        """
    end
  end

  @doc """
  Validates the configuration and returns {:ok, config} or {:error, errors}.
  """
  @spec validate(Config.t()) :: {:ok, Config.t()} | {:error, [String.t()]}
  def validate(%Config{} = config) do
    errors = []

    errors = errors ++ validate_receipts(config)
    errors = errors ++ validate_inbox(config)
    errors = errors ++ validate_scheduled_delivery(config)
    errors = errors ++ validate_media(config)
    errors = errors ++ validate_file_ops(config)
    errors = errors ++ validate_multi_node(config)
    errors = errors ++ validate_postgres_dependency(config)

    if Enum.empty?(errors) do
      {:ok, config}
    else
      {:error, errors}
    end
  end

  # Validation rule implementations

  defp validate_receipts(%Config{features: %{receipts: true}, storage: %{receipts: :none}}) do
    ["Receipts feature is enabled but storage.receipts is set to 'none'. " <>
       "Set storage.receipts to 'postgres' to enable receipts."]
  end

  defp validate_receipts(_config), do: []

  defp validate_inbox(%Config{features: %{inbox: true}, storage: %{inbox: :none}}) do
    ["Inbox feature is enabled but storage.inbox is set to 'none'. " <>
       "Set storage.inbox to 'postgres' or 'redis' to enable inbox."]
  end

  defp validate_inbox(_config), do: []

  defp validate_scheduled_delivery(%Config{
         features: %{scheduled_delivery: true},
         jobs: %{scheduled_delivery: 0}
       }) do
    ["Scheduled delivery feature is enabled but jobs.scheduled_delivery is set to 0. " <>
       "Set a concurrency value greater than 0 for the scheduled_delivery queue."]
  end

  defp validate_scheduled_delivery(_config), do: []

  defp validate_media(%Config{features: %{media: true}, storage: %{blobs: :none}}) do
    ["Media feature is enabled but storage.blobs is set to 'none'. " <>
       "Set storage.blobs to 's3' or 'local' to enable media processing."]
  end

  defp validate_media(%Config{features: %{media: true}, jobs: %{heavy_io: 0}}) do
    ["Media feature is enabled but jobs.heavy_io is set to 0. " <>
       "Set a concurrency value greater than 0 for the heavy_io queue."]
  end

  defp validate_media(_config), do: []

  defp validate_file_ops(%Config{features: %{file_ops: true}, jobs: %{files: 0}}) do
    ["File operations feature is enabled but jobs.files is set to 0. " <>
       "Set a concurrency value greater than 0 for the files queue."]
  end

  defp validate_file_ops(_config), do: []

  defp validate_multi_node(%Config{scaling: %{mode: :multi_node}, storage: %{messages: storage}})
       when storage != :postgres do
    ["Multi-node scaling mode requires postgres storage for messages. " <>
       "Set storage.messages to 'postgres' (current: #{storage})."]
  end

  defp validate_multi_node(_config), do: []

  defp validate_postgres_dependency(%Config{storage: storage}) do
    uses_postgres =
      Enum.any?(storage, fn {_key, value} -> value == :postgres end)

    if uses_postgres do
      # Check if Repo is configured
      case Application.get_env(:messaging_core, :ecto_repos) do
        nil ->
          ["Postgres storage is configured but Messaging.Repo is not in ecto_repos. " <>
             "Ensure Messaging.Repo is properly configured in config.exs."]

        repos when is_list(repos) ->
          if Messaging.Repo in repos do
            []
          else
            ["Postgres storage is configured but Messaging.Repo is not in ecto_repos list. " <>
               "Add Messaging.Repo to the ecto_repos configuration."]
          end

        _ ->
          []
      end
    else
      []
    end
  end

  # Helper functions

  defp format_errors(errors) do
    errors
    |> Enum.with_index(1)
    |> Enum.map(fn {error, index} -> "  #{index}. #{error}" end)
    |> Enum.join("\n")
  end
end
