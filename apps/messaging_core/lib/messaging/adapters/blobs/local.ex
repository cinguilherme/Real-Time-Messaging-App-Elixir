defmodule Messaging.Adapters.Blobs.Local do
  @moduledoc """
  Local filesystem implementation of the BlobStore behavior.
  Useful for development and testing.
  """

  @behaviour Messaging.Behaviors.BlobStore

  require Logger

  @impl true
  def put(key, data, opts \\ []) do
    path = build_path(key)

    with :ok <- ensure_directory(path),
         :ok <- File.write(path, data) do
      # Store metadata if provided
      metadata = Keyword.get(opts, :metadata, %{})

      if map_size(metadata) > 0 do
        write_metadata(path, metadata)
      end

      url = build_url(key)
      {:ok, url}
    else
      {:error, reason} ->
        Logger.error("Failed to write local file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get(key) do
    path = build_path(key)

    case File.read(path) do
      {:ok, data} ->
        {:ok, data}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to read local file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def delete(key) do
    path = build_path(key)
    metadata_path = metadata_path(path)

    # Delete the file
    case File.rm(path) do
      :ok ->
        # Also delete metadata if it exists
        File.rm(metadata_path)
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete local file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def exists?(key) do
    path = build_path(key)
    {:ok, File.exists?(path)}
  end

  @impl true
  def presigned_url(key, _opts \\ []) do
    # For local storage, presigned URLs are just the regular URL
    # In a real implementation, you might generate a time-limited token
    url = build_url(key)
    {:ok, url}
  end

  # Private functions

  defp get_storage_dir do
    Application.get_env(:messaging_core, :local_storage_dir, "priv/storage")
  end

  defp build_path(key) do
    storage_dir = get_storage_dir()
    Path.join(storage_dir, key)
  end

  defp build_url(key) do
    base_url = Application.get_env(:messaging_core, :local_storage_url, "http://localhost:4000/storage")
    "#{base_url}/#{key}"
  end

  defp ensure_directory(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp metadata_path(file_path) do
    "#{file_path}.meta.json"
  end

  defp write_metadata(file_path, metadata) do
    metadata_path = metadata_path(file_path)
    json = Jason.encode!(metadata)
    File.write(metadata_path, json)
  end
end
