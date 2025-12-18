defmodule Messaging.Adapters.History.Noop do
  @moduledoc """
  No-op implementation of the HistoryStore behavior.
  Returns empty results without actually storing or querying history.

  Use this when message history feature is disabled in configuration.
  """

  @behaviour Messaging.Behaviors.HistoryStore

  require Logger

  @impl true
  def store_message(_message) do
    Logger.debug("History disabled: skipping message storage")
    :ok
  end

  @impl true
  def get_conversation_history(_conversation_id, _opts \\ []) do
    {:ok, []}
  end

  @impl true
  def count_messages(_conversation_id) do
    {:ok, 0}
  end

  @impl true
  def search_messages(_conversation_id, _query, _opts \\ []) do
    {:ok, []}
  end

  @impl true
  def delete_conversation_history(_conversation_id) do
    {:ok, 0}
  end
end
