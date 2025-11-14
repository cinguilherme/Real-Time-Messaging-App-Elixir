defmodule Messaging.Repo.Migrations.CreateReceipts do
  use Ecto.Migration

  def change do
    create table(:receipts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :binary_id, null: false
      add :status, :string, null: false
      add :at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:receipts, [:message_id])
    create index(:receipts, [:user_id])
    create index(:receipts, [:message_id, :user_id])
  end
end
