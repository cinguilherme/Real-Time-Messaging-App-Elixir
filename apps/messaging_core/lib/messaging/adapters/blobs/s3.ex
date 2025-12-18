defmodule Messaging.Adapters.Blobs.S3 do
  @moduledoc """
  Amazon S3 implementation of the BlobStore behavior.
  Uses ExAws for S3 operations.
  """

  @behaviour Messaging.Behaviors.BlobStore

  require Logger

  @impl true
  def put(key, data, opts \\ []) do
    bucket = get_bucket()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    acl = Keyword.get(opts, :acl, :private)
    metadata = Keyword.get(opts, :metadata, %{})

    put_opts = [
      content_type: content_type,
      acl: acl,
      meta: metadata
    ]

    case ExAws.S3.put_object(bucket, key, data, put_opts) |> ExAws.request() do
      {:ok, _response} ->
        url = build_url(bucket, key)
        {:ok, url}

      {:error, reason} ->
        Logger.error("Failed to upload to S3: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get(key) do
    bucket = get_bucket()

    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, reason} ->
        Logger.error("Failed to get from S3: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def delete(key) do
    bucket = get_bucket()

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete from S3: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def exists?(key) do
    bucket = get_bucket()

    case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
      {:ok, _response} ->
        {:ok, true}

      {:error, {:http_error, 404, _}} ->
        {:ok, false}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def presigned_url(key, opts \\ []) do
    bucket = get_bucket()
    expires_in = Keyword.get(opts, :expires_in, 3600)

    config = ExAws.Config.new(:s3)

    {:ok, :s3
     |> ExAws.S3.presigned_url(:get, bucket, key, expires_in: expires_in)
     |> ExAws.S3.Presigned.presigned_url(config)}
  rescue
    e ->
      Logger.error("Failed to generate presigned URL: #{inspect(e)}")
      {:error, e}
  end

  # Private functions

  defp get_bucket do
    Application.get_env(:messaging_core, :s3_bucket) ||
      raise "S3 bucket not configured. Set :s3_bucket in :messaging_core config."
  end

  defp build_url(bucket, key) do
    region = Application.get_env(:messaging_core, :s3_region, "us-east-1")
    "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end
end
