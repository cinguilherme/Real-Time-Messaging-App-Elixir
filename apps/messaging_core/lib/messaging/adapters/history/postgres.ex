defmodule Messaging.Adapters.History.Postgres do
  @moduledoc """
  PostgreSQL implementation of the HistoryStore behavior.
  Queries the messages table for conversation history.
  """

  @behaviour Messaging.Behaviors.HistoryStore

  import Ecto.Query
  alias Messaging.Repo
  alias Messaging.Schemas.Message

  @impl true
  def store_message(_message) do
    # Messages are already stored when created, so this is a no-op
    # for the Postgres implementation
    :ok
  end

  @impl true
  def get_conversation_history(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :desc)
    before = Keyword.get(opts, :before)
    after_id = Keyword.get(opts, :after)

    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id

    query =
      if before do
        from m in query, where: m.id < ^before
      else
        query
      end

    query =
      if after_id do
        from m in query, where: m.id > ^after_id
      else
        query
      end

    query =
      case order do
        :asc -> from m in query, order_by: [asc: m.inserted_at]
        :desc -> from m in query, order_by: [desc: m.inserted_at]
      end

    query =
      from m in query,
        limit: ^limit,
        offset: ^offset

    {:ok, Repo.all(query)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def count_messages(conversation_id) do
    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        select: count(m.id)

    {:ok, Repo.one(query)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def search_messages(conversation_id, search_query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    case_sensitive = Keyword.get(opts, :case_sensitive, false)

    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id

    # Search in the body JSONB field
    query =
      if case_sensitive do
        from m in query,
          where: fragment("?::text ILIKE ?", m.body, ^"%#{search_query}%")
      else
        from m in query,
          where: fragment("LOWER(?::text) LIKE LOWER(?)", m.body, ^"%#{search_query}%")
      end

    query =
      from m in query,
        order_by: [desc: m.inserted_at],
        limit: ^limit

    {:ok, Repo.all(query)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def delete_conversation_history(conversation_id) do
    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id

    case Repo.delete_all(query) do
      {count, _} -> {:ok, count}
    end
  rescue
    e -> {:error, e}
  end
end
