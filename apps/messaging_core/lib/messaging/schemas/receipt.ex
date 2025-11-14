defmodule Messaging.Schemas.Receipt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "receipts" do
    belongs_to :message, Messaging.Schemas.Message
    field :user_id, :binary_id
    field :status, Ecto.Enum, values: [:delivered, :read]
    field :at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(receipt, attrs) do
    receipt
    |> cast(attrs, [:message_id, :user_id, :status, :at])
    |> validate_required([:message_id, :user_id, :status, :at])
    |> foreign_key_constraint(:message_id)
  end
end
