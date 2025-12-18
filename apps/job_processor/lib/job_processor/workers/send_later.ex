defmodule JobProcessor.Workers.SendLater do
  @moduledoc """
  Worker for scheduled message delivery.
  Uses Oban's scheduled_at feature to delay execution until the specified time.
  Example: Send at 13:00 but schedule delivery for 14:00.
  """
  use Oban.Worker, queue: :scheduled_delivery, max_attempts: 5

  require Logger
  alias Messaging.{Messages, Receipts, Inbox}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => message_id, "user_id" => user_id} = args}) do
    # Steps:
    # 1. Fetch message by ID
    # 2. Check idempotency (already delivered?)
    # 3. Deliver/publish message at the scheduled time
    # 4. Update status to delivered and set delivered_at
    # 5. Record receipt via context module (uses configured adapter)
    # 6. Mark as delivered in inbox via context module
    # 7. Broadcast delivered event via PubSub

    Logger.info("Delivering scheduled message #{message_id} to user #{user_id}")

    # Example usage of context modules:
    # These will use the configured adapters (Postgres or Noop)
    with :ok <- Receipts.record_delivery(message_id, user_id),
         :ok <- Inbox.mark_delivered(user_id, message_id) do
      Logger.info("Scheduled message #{message_id} delivered successfully")
      {:ok, args}
    else
      {:error, reason} ->
        Logger.error("Failed to deliver scheduled message #{message_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job args for SendLater: #{inspect(args)}")
    {:error, :invalid_args}
  end
end
