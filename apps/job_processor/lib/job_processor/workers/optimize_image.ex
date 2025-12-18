defmodule JobProcessor.Workers.OptimizeImage do
  @moduledoc """
  Worker for heavy image optimization tasks.
  Runs in a dedicated queue with limited concurrency to avoid overwhelming the system.
  """
  use Oban.Worker, queue: :heavy_io, max_attempts: 3

  require Logger
  alias Messaging.Blobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"key" => key} = args}) do
    # Steps:
    # 1. Fetch image from storage via Blobs context module
    # 2. Optimize/compress image
    # 3. Save optimized version via Blobs context module
    # 4. Update references

    Logger.info("Optimizing image: #{key}")

    # Example usage of Blobs context module:
    # This will use the configured adapter (S3, Local, or Noop)
    with {:ok, image_data} <- Blobs.get(key),
         {:ok, optimized_data} <- optimize_image(image_data),
         {:ok, _url} <- Blobs.put("#{key}_optimized", optimized_data, content_type: "image/jpeg") do
      Logger.info("Image #{key} optimized successfully")
      {:ok, args}
    else
      {:error, reason} ->
        Logger.error("Failed to optimize image #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job args for OptimizeImage: #{inspect(args)}")
    {:error, :invalid_args}
  end

  # Placeholder for actual image optimization logic
  defp optimize_image(image_data) do
    # TODO: Implement actual image optimization
    # For now, just return the original data
    {:ok, image_data}
  end
end
