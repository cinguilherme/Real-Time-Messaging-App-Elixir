defmodule Messaging.Receipts do
  @moduledoc """
  Context module for receipt operations.
  Delegates to the configured adapter (Postgres or Noop).
  """

  @doc """
  Records a delivery receipt for a message to a specific user.
  """
  @spec record_delivery(binary(), binary()) :: :ok | {:error, term()}
  def record_delivery(message_id, user_id) do
    adapter().record_delivery(message_id, user_id)
  end

  @doc """
  Records a read receipt for a message from a specific user.
  """
  @spec record_read(binary(), binary()) :: :ok | {:error, term()}
  def record_read(message_id, user_id) do
    adapter().record_read(message_id, user_id)
  end

  @doc """
  Gets all receipts for a given message.
  """
  @spec get_receipts(binary()) :: {:ok, [Messaging.Schemas.Receipt.t()]} | {:error, term()}
  def get_receipts(message_id) do
    adapter().get_receipts(message_id)
  end

  @doc """
  Gets receipts for a message filtered by status.
  """
  @spec get_receipts_by_status(binary(), :delivered | :read) ::
          {:ok, [Messaging.Schemas.Receipt.t()]} | {:error, term()}
  def get_receipts_by_status(message_id, status) do
    adapter().get_receipts_by_status(message_id, status)
  end

  # Private

  defp adapter do
    Application.get_env(
      :messaging_core,
      :receipts_adapter,
      Messaging.Adapters.Receipts.Noop
    )
  end
end
