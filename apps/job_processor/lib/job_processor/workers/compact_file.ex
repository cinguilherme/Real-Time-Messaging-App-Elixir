defmodule JobProcessor.Workers.CompactFile do
  @moduledoc """
  Worker for file compaction tasks.
  Runs in a dedicated queue for file operations.
  """
  use Oban.Worker, queue: :files, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Implementation will be added later
    # Steps:
    # 1. Fetch file from storage
    # 2. Compact/compress file
    # 3. Save compacted version
    # 4. Update references

    {:ok, args}
  end
end
