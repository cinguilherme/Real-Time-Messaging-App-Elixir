defmodule JobProcessor.Workers.OptimizeImage do
  @moduledoc """
  Worker for heavy image optimization tasks.
  Runs in a dedicated queue with limited concurrency to avoid overwhelming the system.
  """
  use Oban.Worker, queue: :heavy_io, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Implementation will be added later
    # Steps:
    # 1. Fetch image from storage
    # 2. Optimize/compress image
    # 3. Save optimized version
    # 4. Update references

    {:ok, args}
  end
end
