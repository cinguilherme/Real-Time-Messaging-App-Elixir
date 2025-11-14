defmodule Messaging.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, :binary_id, null: false
      add :sender_id, :binary_id, null: false
      add :seq, :integer
      add :body, :map, null: false
      add :status, :string, null: false, default: "queued"
      add :scheduled_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :delivered_at, :utc_datetime
      add :read_at, :utc_datetime
      add :idempotency_key, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:messages, [:idempotency_key])
    create index(:messages, [:conversation_id, :seq])
    create index(:messages, [:conversation_id])
    create index(:messages, [:status])
    create index(:messages, [:scheduled_at])
  end
end
