defmodule LocationSharingWeb.LocationChannel do
  @moduledoc """
  Phoenix Channel for real-time location sharing communication.

  Handles:
  - Location updates from clients
  - Broadcasting location updates to session participants
  - Ping/pong for connection health
  - Participant join/leave notifications
  """

  use LocationSharingWeb, :channel

  require Logger

  alias LocationSharing.{Repo}
  alias LocationSharing.Sessions.{Session, Participant, SessionServer}

  @impl true
  def join("location:" <> session_id, _payload, socket) do
    Logger.debug("Channel join attempt for session #{session_id}")
    
    # Verify the user is authenticated and session matches
    case socket.assigns do
      %{authenticated: true, session_id: ^session_id, user_id: user_id} ->
        # Validate session is still active
        case validate_active_session(session_id) do
          {:ok, _session} ->
            Logger.info("User #{user_id} joined location channel for session #{session_id}")
            
            # Subscribe to session events
            Phoenix.PubSub.subscribe(LocationSharing.PubSub, "session:#{session_id}")
            
            # Get participant data from database
            participant_data = case Repo.one(Participant.by_session_and_user(session_id, user_id)) do
              nil ->
                Logger.warning("Participant #{user_id} not found in session #{session_id}")
                %{display_name: "Unknown", avatar_color: "#FF5733"}
              
              participant ->
                %{
                  display_name: participant.display_name,
                  avatar_color: participant.avatar_color
                }
            end
            
            # Add participant to session server (this will start the server if needed)
            case SessionServer.add_participant(session_id, user_id, participant_data) do
              :ok ->
                Logger.info("User #{user_id} added to SessionServer for session #{session_id}")
              
              {:error, reason} ->
                Logger.error("Failed to add user #{user_id} to SessionServer: #{reason}")
                # Continue anyway, the user might already be in the session
            end
            
            # Update participant last_seen in database
            update_participant_activity(session_id, user_id)
            
            socket = 
              socket
              |> assign(:joined_at, DateTime.utc_now())
            
            # Schedule sending initial state after join is complete
            Process.send_after(self(), {:send_initial_state, session_id}, 100)
            
            {:ok, %{status: "joined", session_id: session_id}, socket}

          {:error, reason} ->
            Logger.warning("Failed to join session #{session_id}: #{reason}")
            {:error, %{reason: reason}}
        end

      %{authenticated: true, session_id: different_session} ->
        Logger.warning("Session mismatch: token for #{different_session}, trying to join #{session_id}")
        {:error, %{reason: "unauthorized"}}

      _ ->
        Logger.warning("Unauthenticated channel join attempt")
        {:error, %{reason: "unauthenticated"}}
    end
  end

  @impl true
  def handle_in("location_update", %{"lat" => lat, "lng" => lng, "accuracy" => accuracy, "timestamp" => timestamp}, socket) do
    %{session_id: session_id, user_id: user_id} = socket.assigns
    
    Logger.debug("Location update from user #{user_id}: lat=#{lat}, lng=#{lng}")
    
    # Validate location data
    case validate_location_data(lat, lng, accuracy) do
      :ok ->
        location_data = %{
          lat: lat,
          lng: lng,
          accuracy: accuracy,
          timestamp: timestamp
        }
        
        # Store in SessionServer
        case SessionServer.update_location(session_id, user_id, location_data) do
          :ok ->
            # Update participant activity in database
            update_participant_activity(session_id, user_id)
            
            # The SessionServer automatically broadcasts the location update
            # via Phoenix.PubSub, so we don't need to broadcast here
            
            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to store location for user #{user_id}: #{inspect(reason)}")
            {:reply, {:error, %{reason: "failed_to_store_location"}}, socket}
        end

      {:error, reason} ->
        Logger.warning("Invalid location data from user #{user_id}: #{reason}")
        {:reply, {:error, %{reason: "invalid_location_data"}}, socket}
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    %{user_id: user_id, session_id: session_id} = socket.assigns
    
    Logger.debug("Ping from user #{user_id}")
    
    # Update participant activity in both SessionServer and database
    SessionServer.update_activity(session_id, user_id)
    update_participant_activity(session_id, user_id)
    
    {:reply, {:ok, %{type: "pong", data: %{}}}, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("Unhandled channel event: #{event} with payload: #{inspect(payload)}")
    {:reply, {:error, %{reason: "unknown_event"}}, socket}
  end

  @impl true
  def handle_info({:send_initial_state, session_id}, socket) do
    send_initial_state(socket, session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:participant_joined, message}, socket) do
    push(socket, "participant_joined", message)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:participant_left, message}, socket) do
    push(socket, "participant_left", message)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_ended, message}, socket) do
    Logger.info("Session ended, notifying user #{socket.assigns.user_id}")
    push(socket, "session_ended", message)
    {:stop, :normal, socket}
  end

  @impl true
  def handle_info({:location_update, message}, socket) do
    # This would be for forwarding specific location updates if needed
    push(socket, "location_update", message)
    {:noreply, socket}
  end

  @impl true
  def handle_info(info, socket) do
    Logger.debug("Unhandled channel info: #{inspect(info)}")
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    %{session_id: session_id, user_id: user_id} = socket.assigns
    
    Logger.info("User #{user_id} disconnected from session #{session_id}: #{inspect(reason)}")
    
    # Remove participant from SessionServer
    case SessionServer.remove_participant(session_id, user_id) do
      :ok ->
        Logger.debug("User #{user_id} removed from SessionServer")
      
      {:error, :session_not_found} ->
        Logger.debug("SessionServer not found for session #{session_id}")
      
      {:error, reason} ->
        Logger.warning("Failed to remove user #{user_id} from SessionServer: #{reason}")
    end
    
    # Note: The database participant record is kept for audit purposes
    # The cleanup worker will mark inactive participants
    
    :ok
  end

  # Private helper functions

  defp validate_active_session(session_id) do
    case Repo.get(Session, session_id) do
      nil ->
        {:error, "session_not_found"}
      
      %Session{is_active: false} ->
        {:error, "session_ended"}
      
      session ->
        if session_expired?(session) do
          {:error, "session_expired"}
        else
          {:ok, session}
        end
    end
  end

  defp session_expired?(%Session{expires_at: nil}), do: false
  defp session_expired?(%Session{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp validate_location_data(lat, lng, accuracy) do
    cond do
      not is_number(lat) or lat < -90 or lat > 90 ->
        {:error, "invalid_latitude"}
      
      not is_number(lng) or lng < -180 or lng > 180 ->
        {:error, "invalid_longitude"}
      
      not is_number(accuracy) or accuracy < 0 ->
        {:error, "invalid_accuracy"}
      
      true ->
        :ok
    end
  end

  defp update_participant_activity(session_id, user_id) do
    # Update last_seen in database
    case Repo.one(Participant.by_session_and_user(session_id, user_id)) do
      nil ->
        Logger.warning("Participant #{user_id} not found in session #{session_id}")
      
      participant ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        changeset = Participant.update_activity_changeset(participant, %{last_seen: now})
        
        case Repo.update(changeset) do
          {:ok, _} -> :ok
          {:error, reason} -> 
            Logger.error("Failed to update participant activity: #{inspect(reason)}")
        end
    end
  end

  defp send_initial_state(socket, session_id) do
    # Send current participants
    case SessionServer.get_participants(session_id) do
      {:ok, participants} ->
        # Filter out the joining user from the participants list
        filtered_participants = Enum.reject(participants, fn participant ->
          participant[:user_id] == socket.assigns.user_id
        end)
        
        push(socket, "initial_participants", %{participants: filtered_participants})
      
      {:error, _} ->
        Logger.warning("Could not fetch initial participants for session #{session_id}")
    end
    
    # Send current locations
    case SessionServer.get_locations(session_id) do
      {:ok, locations} ->
        # Don't send the joining user's own location back
        filtered_locations = Enum.reject(locations, fn location ->
          location[:user_id] == socket.assigns.user_id
        end)
        
        push(socket, "initial_locations", %{locations: filtered_locations})
      
      {:error, _} ->
        Logger.warning("Could not fetch initial locations for session #{session_id}")
    end
  end

end