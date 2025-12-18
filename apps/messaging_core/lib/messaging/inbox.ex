defmodule Messaging.Inbox do
  @moduledoc """
  Context module for inbox operations.
  Delegates to the configured adapter (Postgres or Noop).
  """

  @doc """
  Enqueues a message for a specific user in their inbox.
  """
  @spec enqueue(binary(), binary()) :: :ok | {:error, term()}
  def enqueue(user_id, message_id) do
    adapter().enqueue(user_id, message_id)
  end

  @doc """
  Marks a message as delivered to the user.
  """
  @spec mark_delivered(binary(), binary()) :: :ok | {:error, term()}
  def mark_delivered(user_id, message_id) do
    adapter().mark_delivered(user_id, message_id)
  end

  @doc """
  Gets all pending (undelivered) message IDs for a user.
  """
  @spec pending_messages(binary()) :: {:ok, [binary()]} | {:error, term()}
  def pending_messages(user_id) do
    adapter().pending_messages(user_id)
  end

  @doc """
  Gets pending messages with pagination support.
  """
  @spec pending_messages(binary(), keyword()) :: {:ok, [binary()]} | {:error, term()}
  def pending_messages(user_id, opts) do
    adapter().pending_messages(user_id, opts)
  end

  @doc """
  Clears all delivered messages from a user's inbox.
  """
  @spec clear_delivered(binary()) :: {:ok, non_neg_integer()} | {:error, term()}
  def clear_delivered(user_id) do
    adapter().clear_delivered(user_id)
  end

  # Private

  defp adapter do
    Application.get_env(
      :messaging_core,
      :inbox_adapter,
      Messaging.Adapters.Inbox.Noop
    )
  end
end
