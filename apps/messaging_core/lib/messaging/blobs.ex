defmodule Messaging.Blobs do
  @moduledoc """
  Context module for blob storage operations.
  Delegates to the configured adapter (S3, Local, or Noop).
  """

  @type key :: String.t()
  @type data :: binary()
  @type url :: String.t()
  @type opts :: keyword()

  @doc """
  Stores binary data with a given key.

  Options:
    - :content_type - MIME type of the content
    - :metadata - Additional metadata to store
    - :acl - Access control settings
  """
  @spec put(key(), data(), opts()) :: {:ok, url()} | {:error, term()}
  def put(key, data, opts \\ []) do
    adapter().put(key, data, opts)
  end

  @doc """
  Retrieves binary data by key.
  """
  @spec get(key()) :: {:ok, data()} | {:error, term()}
  def get(key) do
    adapter().get(key)
  end

  @doc """
  Deletes a blob by key.
  """
  @spec delete(key()) :: :ok | {:error, term()}
  def delete(key) do
    adapter().delete(key)
  end

  @doc """
  Checks if a blob exists.
  """
  @spec exists?(key()) :: {:ok, boolean()} | {:error, term()}
  def exists?(key) do
    adapter().exists?(key)
  end

  @doc """
  Generates a presigned URL for temporary access.
  """
  @spec presigned_url(key(), opts()) :: {:ok, url()} | {:error, term()}
  def presigned_url(key, opts \\ []) do
    adapter().presigned_url(key, opts)
  end

  # Private

  defp adapter do
    Application.get_env(
      :messaging_core,
      :blobs_adapter,
      Messaging.Adapters.Blobs.Noop
    )
  end
end
