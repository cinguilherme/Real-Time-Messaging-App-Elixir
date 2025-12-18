defmodule Messaging.Adapters.Inbox.Postgres do
  @moduledoc """
  PostgreSQL implementation of the InboxStore behavior.
  Uses the existing Messaging.Schemas.Inbox schema.
  """

  @behaviour Messaging.Behaviors.InboxStore

  import Ecto.Query
  alias Messaging.Repo
  alias Messaging.Schemas.Inbox

  @impl true
  def enqueue(user_id, message_id) do
    attrs = %{
      user_id: user_id,
      message_id: message_id,
      enqueued_at: DateTime.utc_now(),
      delivered_at: nil
    }

    %Inbox{}
    |> Inbox.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _inbox} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def mark_delivered(user_id, message_id) do
    query =
      from i in Inbox,
        where: i.user_id == ^user_id and i.message_id == ^message_id

    case Repo.update_all(query, set: [delivered_at: DateTime.utc_now()]) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
      _ -> {:error, :unknown}
    end
  rescue
    e -> {:error, e}
  end

  @impl true
  def pending_messages(user_id) do
    pending_messages(user_id, [])
  end

  @impl true
  def pending_messages(user_id, opts) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from i in Inbox,
        where: i.user_id == ^user_id and is_nil(i.delivered_at),
        order_by: [asc: i.enqueued_at],
        limit: ^limit,
        offset: ^offset,
        select: i.message_id

    {:ok, Repo.all(query)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def clear_delivered(user_id) do
    query =
      from i in Inbox,
        where: i.user_id == ^user_id and not is_nil(i.delivered_at)

    case Repo.delete_all(query) do
      {count, _} -> {:ok, count}
    end
  rescue
    e -> {:error, e}
  end
end
