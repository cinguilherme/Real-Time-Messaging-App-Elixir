defmodule JobProcessor.Workers.CompactFile do
  @moduledoc """
  Worker for file compaction tasks.
  Runs in a dedicated queue for file operations.
  """
  use Oban.Worker, queue: :files, max_attempts: 3

  require Logger
  alias Messaging.Blobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"key" => key} = args}) do
    # Steps:
    # 1. Fetch file from storage via Blobs context module
    # 2. Compact/compress file
    # 3. Save compacted version via Blobs context module
    # 4. Update references

    Logger.info("Compacting file: #{key}")

    # Example usage of Blobs context module:
    # This will use the configured adapter (S3, Local, or Noop)
    with {:ok, file_data} <- Blobs.get(key),
         {:ok, compacted_data} <- compact_file(file_data),
         {:ok, _url} <- Blobs.put("#{key}_compact", compacted_data) do
      Logger.info("File #{key} compacted successfully")
      {:ok, args}
    else
      {:error, reason} ->
        Logger.error("Failed to compact file #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job args for CompactFile: #{inspect(args)}")
    {:error, :invalid_args}
  end

  # Placeholder for actual file compaction logic
  defp compact_file(file_data) do
    # TODO: Implement actual file compaction
    # For now, just return the original data
    {:ok, file_data}
  end
end
