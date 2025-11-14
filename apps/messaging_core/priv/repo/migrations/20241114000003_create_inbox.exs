defmodule Messaging.Repo.Migrations.CreateInbox do
  use Ecto.Migration

  def change do
    create table(:inbox, primary_key: false) do
      add :user_id, :binary_id, null: false
      add :message_id, :binary_id, null: false
      add :enqueued_at, :utc_datetime, null: false
      add :delivered_at, :utc_datetime
    end

    create index(:inbox, [:user_id])
    create index(:inbox, [:message_id])
    create unique_index(:inbox, [:user_id, :message_id])
  end
end
