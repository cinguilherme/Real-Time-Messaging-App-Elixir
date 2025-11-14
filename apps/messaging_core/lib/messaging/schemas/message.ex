defmodule Messaging.Schemas.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :conversation_id, :binary_id
    field :sender_id, :binary_id
    field :seq, :integer
    field :body, :map
    field :status, Ecto.Enum, values: [:queued, :delivered, :read, :failed], default: :queued
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :read_at, :utc_datetime
    field :idempotency_key, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :conversation_id,
      :sender_id,
      :seq,
      :body,
      :status,
      :scheduled_at,
      :sent_at,
      :delivered_at,
      :read_at,
      :idempotency_key
    ])
    |> validate_required([:conversation_id, :sender_id, :body])
    |> unique_constraint(:idempotency_key)
  end
end
