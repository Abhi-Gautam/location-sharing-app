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
  alias LocationSharing.Sessions.{Session, Participant}

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
            
            # Verify participant exists in database
            case Repo.one(Participant.by_session_and_user(session_id, user_id)) do
              nil ->
                Logger.warning("Participant #{user_id} not found in session #{session_id}")
              
              _participant ->
                Logger.debug("Participant #{user_id} verified in session #{session_id}")
            end
            
            # Participant is already in database, WebSocket connection handles real-time state
            Logger.info("User #{user_id} connected to location channel for session #{session_id}")
            
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
        
        # Update participant activity in database
        update_participant_activity(session_id, user_id)
        
        # Broadcast location update to all participants in session
        broadcast_location_update(session_id, user_id, location_data)
        
        {:noreply, socket}

      {:error, reason} ->
        Logger.warning("Invalid location data from user #{user_id}: #{reason}")
        {:reply, {:error, %{reason: "invalid_location_data"}}, socket}
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    %{user_id: user_id, session_id: session_id} = socket.assigns
    
    Logger.debug("Ping from user #{user_id}")
    
    # Update participant activity in database
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
    
    # Participant disconnect handled automatically by WebSocket connection
    
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
    # Send current participants from database
    participants = 
      Participant.active_for_session(session_id)
      |> Repo.all()
      |> Enum.reject(fn participant -> participant.user_id == socket.assigns.user_id end)
      |> Enum.map(fn participant ->
        %{
          user_id: participant.user_id,
          display_name: participant.display_name,
          avatar_color: participant.avatar_color
        }
      end)
    
    push(socket, "initial_participants", %{participants: participants})
    
    # Note: Initial locations would need to be stored in database if persistence is required
    # For now, participants will start receiving location updates after joining
    Logger.debug("Sent initial state to user #{socket.assigns.user_id}")
  end
  
  defp broadcast_location_update(session_id, user_id, location_data) do
    message = %{
      type: "location_update",
      data: Map.put(location_data, :user_id, user_id)
    }
    
    Phoenix.PubSub.broadcast(
      LocationSharing.PubSub,
      "session:#{session_id}",
      {:location_update, message}
    )
  end

end