defmodule JobProcessor.Workers.SendMessage do
  @moduledoc """
  Worker for immediate message delivery.
  Fetches message, guards idempotency, delivers/publishes, and sets delivered_at.
  """
  use Oban.Worker, queue: :deliver_realtime, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Implementation will be added later
    # Steps:
    # 1. Fetch message by ID
    # 2. Check idempotency (already delivered?)
    # 3. Deliver/publish message
    # 4. Update status to delivered and set delivered_at
    # 5. Broadcast delivered event via PubSub

    {:ok, args}
  end
end
