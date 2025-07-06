defmodule LocationSharing.Sessions.CleanupWorker do
  @moduledoc """
  Background worker that periodically cleans up expired sessions and inactive participants.

  This GenServer performs the following cleanup tasks:
  - Marks expired sessions as inactive
  - Terminates SessionServer processes for ended sessions
  - Removes inactive participants from sessions
  - Notifies WebSocket channels about session/participant changes
  
  Note: Since we're using BEAM processes instead of Redis, most cleanup
  is handled automatically by SessionServer processes themselves.
  """

  use GenServer
  require Logger

  alias LocationSharing.{Repo}
  alias LocationSharing.Sessions.{Session, Participant, SessionServer}

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
        
        # Terminate SessionServer (this will notify all participants and cleanup automatically)
        case SessionServer.terminate_session(session.id) do
          :ok ->
            Logger.debug("SessionServer terminated for expired session #{session.id}")
          
          {:error, :session_not_found} ->
            Logger.debug("SessionServer not found for expired session #{session.id}")
            # Fallback to manual broadcast if SessionServer is not running
            broadcast_session_ended(updated_session.id, "expired")
        end
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
      # Check database for participants that should be marked inactive
      inactive_db_participants = Repo.all(Participant.inactive_participants(@participant_timeout_minutes))
      
      # Mark database participants as inactive
      Enum.each(inactive_db_participants, fn participant ->
        Logger.debug("Marking participant #{participant.user_id} as inactive in session #{participant.session_id}")
        
        changeset = Participant.leave_changeset(participant)
        {:ok, _} = Repo.update(changeset)
        
        # Remove from SessionServer if still there
        case SessionServer.remove_participant(participant.session_id, participant.user_id) do
          :ok ->
            Logger.debug("Removed inactive participant from SessionServer")
          
          {:error, :session_not_found} ->
            Logger.debug("SessionServer not found for session #{participant.session_id}")
            # Fallback to manual broadcast if SessionServer is not running
            broadcast_participant_left(participant.session_id, participant.user_id)
          
          {:error, :participant_not_found} ->
            Logger.debug("Participant #{participant.user_id} not found in SessionServer")
        end
      end)
      
      if length(inactive_db_participants) > 0 do
        Logger.info("Cleaned up #{length(inactive_db_participants)} inactive participants")
      end
    rescue
      error ->
        Logger.error("Error during participant cleanup: #{inspect(error)}")
    end
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