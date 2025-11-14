defmodule Messaging.Schemas.Inbox do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "inbox" do
    field :user_id, :binary_id
    field :message_id, :binary_id
    field :enqueued_at, :utc_datetime
    field :delivered_at, :utc_datetime
  end

  @doc false
  def changeset(inbox, attrs) do
    inbox
    |> cast(attrs, [:user_id, :message_id, :enqueued_at, :delivered_at])
    |> validate_required([:user_id, :message_id, :enqueued_at])
  end
end
