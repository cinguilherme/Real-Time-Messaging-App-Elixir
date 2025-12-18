defmodule Messaging.Adapters.Blobs.Noop do
  @moduledoc """
  No-op implementation of the BlobStore behavior.
  Returns fake URLs and success responses without actually storing data.

  Use this when media/blob storage is disabled in configuration.
  """

  @behaviour Messaging.Behaviors.BlobStore

  require Logger

  @impl true
  def put(key, _data, _opts \\ []) do
    Logger.debug("Blob storage disabled: skipping put for key #{key}")
    url = "noop://storage/#{key}"
    {:ok, url}
  end

  @impl true
  def get(key) do
    Logger.debug("Blob storage disabled: skipping get for key #{key}")
    {:error, :not_found}
  end

  @impl true
  def delete(key) do
    Logger.debug("Blob storage disabled: skipping delete for key #{key}")
    :ok
  end

  @impl true
  def exists?(_key) do
    {:ok, false}
  end

  @impl true
  def presigned_url(key, _opts \\ []) do
    Logger.debug("Blob storage disabled: returning fake presigned URL for key #{key}")
    url = "noop://storage/#{key}?presigned=true"
    {:ok, url}
  end
end
