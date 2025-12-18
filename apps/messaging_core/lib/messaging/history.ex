defmodule Messaging.History do
  @moduledoc """
  Context module for message history operations.
  Delegates to the configured adapter (Postgres or Noop).
  """

  @type message :: Messaging.Schemas.Message.t()
  @type conversation_id :: binary()
  @type opts :: keyword()

  @doc """
  Stores a message in the history.
  """
  @spec store_message(message()) :: :ok | {:error, term()}
  def store_message(message) do
    adapter().store_message(message)
  end

  @doc """
  Retrieves conversation history.

  Options:
    - :limit - Maximum number of messages
    - :offset - Pagination offset
    - :before - Messages before this ID
    - :after - Messages after this ID
    - :order - :asc or :desc
  """
  @spec get_conversation_history(conversation_id(), opts()) ::
          {:ok, [message()]} | {:error, term()}
  def get_conversation_history(conversation_id, opts \\ []) do
    adapter().get_conversation_history(conversation_id, opts)
  end

  @doc """
  Gets a count of messages in a conversation.
  """
  @spec count_messages(conversation_id()) :: {:ok, non_neg_integer()} | {:error, term()}
  def count_messages(conversation_id) do
    adapter().count_messages(conversation_id)
  end

  @doc """
  Searches messages in a conversation.
  """
  @spec search_messages(conversation_id(), String.t(), opts()) ::
          {:ok, [message()]} | {:error, term()}
  def search_messages(conversation_id, query, opts \\ []) do
    adapter().search_messages(conversation_id, query, opts)
  end

  @doc """
  Deletes message history for a conversation.
  """
  @spec delete_conversation_history(conversation_id()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def delete_conversation_history(conversation_id) do
    adapter().delete_conversation_history(conversation_id)
  end

  # Private

  defp adapter do
    Application.get_env(
      :messaging_core,
      :history_adapter,
      Messaging.Adapters.History.Noop
    )
  end
end
