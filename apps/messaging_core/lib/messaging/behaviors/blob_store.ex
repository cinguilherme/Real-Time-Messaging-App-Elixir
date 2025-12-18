defmodule Messaging.Behaviors.BlobStore do
  @moduledoc """
  Behavior for blob storage implementations.

  Handles storage and retrieval of binary data like images, files, and media.
  Implementations can use S3, local filesystem, or other storage backends.
  """

  @type key :: String.t()
  @type data :: binary()
  @type url :: String.t()
  @type opts :: keyword()

  @doc """
  Stores binary data with a given key.

  Options:
    - :content_type - MIME type of the content
    - :metadata - Additional metadata to store with the blob
    - :acl - Access control settings (e.g., :public_read, :private)

  Returns the URL where the blob can be accessed.
  """
  @callback put(key :: key(), data :: data(), opts :: opts()) ::
              {:ok, url()} | {:error, term()}

  @doc """
  Retrieves binary data by key.
  """
  @callback get(key :: key()) ::
              {:ok, data()} | {:error, term()}

  @doc """
  Deletes a blob by key.
  """
  @callback delete(key :: key()) ::
              :ok | {:error, term()}

  @doc """
  Checks if a blob exists.
  """
  @callback exists?(key :: key()) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  Generates a presigned URL for temporary access to a blob.

  Options:
    - :expires_in - Expiration time in seconds (default: 3600)
  """
  @callback presigned_url(key :: key(), opts :: opts()) ::
              {:ok, url()} | {:error, term()}
end
