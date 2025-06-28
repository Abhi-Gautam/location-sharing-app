defmodule LocationSharing.Sessions.CleanupWorker do
  @moduledoc """
  Background worker that periodically cleans up expired sessions and inactive participants.

  This GenServer performs the following cleanup tasks:
  - Marks expired sessions as inactive
  - Removes inactive participants from sessions
  - Cleans up Redis data for ended sessions
  - Notifies WebSocket channels about session/participant changes
  """

  use GenServer
  require Logger

  alias LocationSharing.{Repo, Redis}
  alias LocationSharing.Sessions.{Session, Participant}

  # Run cleanup every 5 minutes
  @cleanup_interval :timer.minutes(5)
  
  # Consider participants inactive after 30 minutes of no location updates
  @participant_timeout_minutes 30

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule the first cleanup
    schedule_cleanup()
    
    Logger.info("Session cleanup worker started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.debug("Starting session and participant cleanup")
    
    # Perform cleanup tasks
    cleanup_expired_sessions()
    cleanup_inactive_participants()
    cleanup_orphaned_redis_data()
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message in cleanup worker: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired_sessions do
    Logger.debug("Cleaning up expired sessions")
    
    try do
      expired_sessions = Repo.all(Session.expired_sessions())
      
      Enum.each(expired_sessions, fn session ->
        Logger.info("Ending expired session: #{session.id}")
        
        # Mark session as inactive
        changeset = Session.end_session_changeset(session)
        {:ok, updated_session} = Repo.update(changeset)
        
        # Notify all participants via WebSocket
        broadcast_session_ended(updated_session.id, "expired")
        
        # Cleanup Redis data
        Redis.cleanup_session(session.id)
      end)
      
      if length(expired_sessions) > 0 do
        Logger.info("Cleaned up #{length(expired_sessions)} expired sessions")
      end
    rescue
      error ->
        Logger.error("Error during session cleanup: #{inspect(error)}")
    end
  end

  defp cleanup_inactive_participants do
    Logger.debug("Cleaning up inactive participants")
    
    try do
      # Find participants that haven't been seen recently in Redis
      inactive_redis_participants = find_inactive_redis_participants()
      
      # Also check database for participants that should be marked inactive
      inactive_db_participants = Repo.all(Participant.inactive_participants(@participant_timeout_minutes))
      
      # Clean up Redis participants
      Enum.each(inactive_redis_participants, fn {session_id, user_id} ->
        Logger.debug("Removing inactive participant #{user_id} from session #{session_id}")
        Redis.remove_session_participant(session_id, user_id)
        broadcast_participant_left(session_id, user_id)
      end)
      
      # Mark database participants as inactive
      Enum.each(inactive_db_participants, fn participant ->
        Logger.debug("Marking participant #{participant.user_id} as inactive in session #{participant.session_id}")
        
        changeset = Participant.leave_changeset(participant)
        {:ok, _} = Repo.update(changeset)
        
        # Remove from Redis if still there
        Redis.remove_session_participant(participant.session_id, participant.user_id)
        broadcast_participant_left(participant.session_id, participant.user_id)
      end)
      
      total_cleaned = length(inactive_redis_participants) + length(inactive_db_participants)
      if total_cleaned > 0 do
        Logger.info("Cleaned up #{total_cleaned} inactive participants")
      end
    rescue
      error ->
        Logger.error("Error during participant cleanup: #{inspect(error)}")
    end
  end

  defp cleanup_orphaned_redis_data do
    Logger.debug("Cleaning up orphaned Redis data")
    
    try do
      # This would typically involve scanning Redis keys and checking against database
      # For now, we rely on TTL expiration for most cleanup
      # Could implement more sophisticated cleanup if needed
      :ok
    rescue
      error ->
        Logger.error("Error during Redis cleanup: #{inspect(error)}")
    end
  end

  defp find_inactive_redis_participants do
    # This is a simplified implementation
    # In a real application, you might scan Redis for all session participants
    # and check their last location update times
    
    # For now, return empty list as Redis TTL handles most cleanup
    []
  end

  defp broadcast_session_ended(session_id, reason) do
    message = %{
      type: "session_ended",
      data: %{reason: reason}
    }
    
    Phoenix.PubSub.broadcast(
      LocationSharing.PubSub,
      "session:#{session_id}",
      {:session_ended, message}
    )
  end

  defp broadcast_participant_left(session_id, user_id) do
    message = %{
      type: "participant_left",
      data: %{user_id: user_id}
    }
    
    Phoenix.PubSub.broadcast(
      LocationSharing.PubSub,
      "session:#{session_id}",
      {:participant_left, message}
    )
  end
end