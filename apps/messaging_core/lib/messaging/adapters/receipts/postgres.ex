defmodule Messaging.Adapters.Receipts.Postgres do
  @moduledoc """
  PostgreSQL implementation of the ReceiptsStore behavior.
  Uses the existing Messaging.Schemas.Receipt schema.
  """

  @behaviour Messaging.Behaviors.ReceiptsStore

  import Ecto.Query
  alias Messaging.Repo
  alias Messaging.Schemas.Receipt

  @impl true
  def record_delivery(message_id, user_id) do
    attrs = %{
      message_id: message_id,
      user_id: user_id,
      status: :delivered,
      at: DateTime.utc_now()
    }

    %Receipt{}
    |> Receipt.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _receipt} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def record_read(message_id, user_id) do
    attrs = %{
      message_id: message_id,
      user_id: user_id,
      status: :read,
      at: DateTime.utc_now()
    }

    %Receipt{}
    |> Receipt.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _receipt} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def get_receipts(message_id) do
    query =
      from r in Receipt,
        where: r.message_id == ^message_id,
        order_by: [desc: r.inserted_at]

    {:ok, Repo.all(query)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def get_receipts_by_status(message_id, status) do
    query =
      from r in Receipt,
        where: r.message_id == ^message_id and r.status == ^status,
        order_by: [desc: r.inserted_at]

    {:ok, Repo.all(query)}
  rescue
    e -> {:error, e}
  end
end
