defmodule LocationSharing.Repo.Migrations.CreateSessionsAndParticipants do
  use Ecto.Migration

  def change do
    # Create sessions table
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, size: 255
      add :creator_id, :binary_id
      add :is_active, :boolean, default: true, null: false
      add :last_activity, :utc_datetime, default: fragment("NOW()"), null: false
      add :expires_at, :utc_datetime
      
      timestamps(type: :utc_datetime, inserted_at: :created_at)
    end

    # Create participants table
    create table(:participants, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :string, size: 255, null: false
      add :display_name, :string, size: 100, null: false
      add :avatar_color, :string, size: 7, default: "#FF5733"
      add :last_seen, :utc_datetime, default: fragment("NOW()"), null: false
      add :is_active, :boolean, default: true, null: false
      
      timestamps(type: :utc_datetime, inserted_at: :joined_at)
    end

    # Create indexes for performance
    create index(:sessions, [:is_active, :expires_at], name: :idx_sessions_active)
    create index(:sessions, [:last_activity], name: :idx_sessions_activity)
    create index(:participants, [:session_id, :is_active], name: :idx_participants_session)
    create index(:participants, [:user_id])
  end
end
