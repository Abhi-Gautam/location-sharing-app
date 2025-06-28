defmodule LocationSharing.Repo.Migrations.AddUniqueConstraintsToParticipants do
  use Ecto.Migration

  def change do
    # Ensure user_id is unique within a session
    create unique_index(:participants, [:session_id, :user_id], name: :participants_session_id_user_id_index)
    
    # Ensure display_name is unique within a session
    create unique_index(:participants, [:session_id, :display_name], name: :participants_session_id_display_name_index)
  end
end
