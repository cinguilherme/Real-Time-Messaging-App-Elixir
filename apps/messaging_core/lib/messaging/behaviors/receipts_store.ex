defmodule Messaging.Behaviors.ReceiptsStore do
  @moduledoc """
  Behavior for receipt tracking implementations.

  Receipts track per-user delivery and read status for messages,
  especially important in group conversations.
  """

  @doc """
  Records a delivery receipt for a message to a specific user.
  """
  @callback record_delivery(message_id :: binary(), user_id :: binary()) ::
              :ok | {:error, term()}

  @doc """
  Records a read receipt for a message from a specific user.
  """
  @callback record_read(message_id :: binary(), user_id :: binary()) ::
              :ok | {:error, term()}

  @doc """
  Gets all receipts for a given message.
  """
  @callback get_receipts(message_id :: binary()) ::
              {:ok, [Messaging.Schemas.Receipt.t()]} | {:error, term()}

  @doc """
  Gets receipts for a message filtered by status.
  """
  @callback get_receipts_by_status(message_id :: binary(), status :: :delivered | :read) ::
              {:ok, [Messaging.Schemas.Receipt.t()]} | {:error, term()}
end
