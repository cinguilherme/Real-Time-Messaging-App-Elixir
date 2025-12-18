defmodule Messaging.Config.Loader do
  @moduledoc """
  Loads and parses feature configuration from YAML files.
  """

  require Logger
  alias Messaging.Config

  @doc """
  Loads the configuration from the configured path.
  Raises on failure with a clear error message.
  """
  @spec load!() :: Config.t()
  def load! do
    path = config_path()

    case File.read(path) do
      {:ok, content} ->
        content
        |> parse_yaml!()
        |> to_config_struct()
        |> Messaging.Config.Validator.validate!()

      {:error, :enoent} ->
        raise """
        Feature configuration file not found: #{path}

        Set FEATURES_CONFIG environment variable to specify the config file path,
        or ensure config/features.yaml exists.

        Example:
          export FEATURES_CONFIG=/etc/app/features.yaml
        """

      {:error, reason} ->
        raise "Failed to read feature configuration from #{path}: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the path to the feature configuration file.
  """
  @spec config_path() :: String.t()
  def config_path do
    Application.get_env(:messaging_core, :features_config_path, "config/features.yaml")
  end

  @doc """
  Reloads the configuration from disk.
  Useful for runtime configuration updates.
  """
  @spec reload!() :: Config.t()
  def reload! do
    # Clear any cached config
    Application.delete_env(:messaging_core, :cached_config)
    load!()
  end

  # Private functions

  defp parse_yaml!(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, data} ->
        data

      {:error, error} ->
        raise "Failed to parse YAML configuration: #{inspect(error)}"
    end
  end

  defp to_config_struct(data) do
    %Config{
      features: %{
        receipts: get_in(data, ["features", "receipts"]) || false,
        inbox: get_in(data, ["features", "inbox"]) || false,
        scheduled_delivery: get_in(data, ["features", "scheduled_delivery"]) || false,
        media: get_in(data, ["features", "media"]) || false,
        file_ops: get_in(data, ["features", "file_ops"]) || false,
        pubsub: get_in(data, ["features", "pubsub"]) || false
      },
      storage: %{
        messages: parse_storage_value(get_in(data, ["storage", "messages"]), :postgres),
        receipts: parse_storage_value(get_in(data, ["storage", "receipts"]), :none),
        inbox: parse_storage_value(get_in(data, ["storage", "inbox"]), :none),
        history: parse_storage_value(get_in(data, ["storage", "history"]), :none),
        blobs: parse_storage_value(get_in(data, ["storage", "blobs"]), :none)
      },
      scaling: %{
        mode: parse_atom_value(get_in(data, ["scaling", "mode"]), :single_node),
        job_isolation: get_in(data, ["scaling", "job_isolation"]) || false
      },
      jobs: %{
        deliver_realtime: get_in(data, ["jobs", "deliver_realtime"]) || 0,
        scheduled_delivery: get_in(data, ["jobs", "scheduled_delivery"]) || 0,
        files: get_in(data, ["jobs", "files"]) || 0,
        heavy_io: get_in(data, ["jobs", "heavy_io"]) || 0
      }
    }
  end

  defp parse_storage_value(nil, default), do: default

  defp parse_storage_value(value, _default) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> raise "Invalid storage value: #{value}"
  end

  defp parse_storage_value(value, default) when is_atom(value), do: value || default

  defp parse_atom_value(nil, default), do: default

  defp parse_atom_value(value, _default) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> raise "Invalid atom value: #{value}"
  end

  defp parse_atom_value(value, default) when is_atom(value), do: value || default
end
