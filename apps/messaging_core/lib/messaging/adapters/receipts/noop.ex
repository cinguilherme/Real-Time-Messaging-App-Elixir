defmodule Messaging.Adapters.Receipts.Noop do
  @moduledoc """
  No-op implementation of the ReceiptsStore behavior.
  Returns success immediately without actually storing receipts.

  Use this when the receipts feature is disabled in configuration.
  """

  @behaviour Messaging.Behaviors.ReceiptsStore

  require Logger

  @impl true
  def record_delivery(_message_id, _user_id) do
    Logger.debug("Receipts disabled: skipping delivery receipt")
    :ok
  end

  @impl true
  def record_read(_message_id, _user_id) do
    Logger.debug("Receipts disabled: skipping read receipt")
    :ok
  end

  @impl true
  def get_receipts(_message_id) do
    {:ok, []}
  end

  @impl true
  def get_receipts_by_status(_message_id, _status) do
    {:ok, []}
  end
end
