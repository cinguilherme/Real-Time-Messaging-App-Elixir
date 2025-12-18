defmodule Messaging.Behaviors.InboxStore do
  @moduledoc """
  Behavior for inbox queue implementations.

  The inbox stores messages that are waiting to be delivered to offline users.
  When a user reconnects, pending messages are delivered from their inbox.
  """

  @doc """
  Enqueues a message for a specific user in their inbox.
  """
  @callback enqueue(user_id :: binary(), message_id :: binary()) ::
              :ok | {:error, term()}

  @doc """
  Marks a message as delivered to the user, removing it from pending queue.
  """
  @callback mark_delivered(user_id :: binary(), message_id :: binary()) ::
              :ok | {:error, term()}

  @doc """
  Gets all pending (undelivered) message IDs for a user.
  """
  @callback pending_messages(user_id :: binary()) ::
              {:ok, [binary()]} | {:error, term()}

  @doc """
  Gets pending messages with pagination support.
  """
  @callback pending_messages(user_id :: binary(), opts :: keyword()) ::
              {:ok, [binary()]} | {:error, term()}

  @doc """
  Clears all delivered messages from a user's inbox.
  Useful for cleanup operations.
  """
  @callback clear_delivered(user_id :: binary()) ::
              {:ok, non_neg_integer()} | {:error, term()}
end
