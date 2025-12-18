defmodule Messaging.Adapters.Inbox.Noop do
  @moduledoc """
  No-op implementation of the InboxStore behavior.
  Returns success immediately without actually storing inbox entries.

  Use this when the inbox feature is disabled in configuration.
  Messages will be delivered immediately instead of queued.
  """

  @behaviour Messaging.Behaviors.InboxStore

  require Logger

  @impl true
  def enqueue(_user_id, _message_id) do
    Logger.debug("Inbox disabled: skipping message enqueue")
    :ok
  end

  @impl true
  def mark_delivered(_user_id, _message_id) do
    Logger.debug("Inbox disabled: skipping mark delivered")
    :ok
  end

  @impl true
  def pending_messages(_user_id) do
    {:ok, []}
  end

  @impl true
  def pending_messages(_user_id, _opts) do
    {:ok, []}
  end

  @impl true
  def clear_delivered(_user_id) do
    {:ok, 0}
  end
end
