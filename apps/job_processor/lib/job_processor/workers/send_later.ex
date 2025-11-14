defmodule JobProcessor.Workers.SendLater do
  @moduledoc """
  Worker for scheduled message delivery.
  Uses Oban's scheduled_at feature to delay execution until the specified time.
  Example: Send at 13:00 but schedule delivery for 14:00.
  """
  use Oban.Worker, queue: :scheduled_delivery, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Implementation will be added later
    # Steps:
    # 1. Fetch message by ID
    # 2. Check idempotency (already delivered?)
    # 3. Deliver/publish message at the scheduled time
    # 4. Update status to delivered and set delivered_at
    # 5. Broadcast delivered event via PubSub

    {:ok, args}
  end
end
