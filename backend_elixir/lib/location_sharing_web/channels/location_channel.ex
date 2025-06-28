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

  alias LocationSharing.{Repo, Redis}
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
            
            # Store connection mapping in Redis
            connection_id = generate_connection_id()
            Redis.set_connection(user_id, connection_id)
            
            # Add to Redis session participants if not already there
            Redis.add_session_participant(session_id, user_id)
            
            # Update participant last_seen in database
            update_participant_activity(session_id, user_id)
            
            # Send current session state to the joining participant
            send_initial_state(socket, session_id)
            
            socket = 
              socket
              |> assign(:connection_id, connection_id)
              |> assign(:joined_at, DateTime.utc_now())
            
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
        
        # Store in Redis with TTL
        case Redis.set_location(session_id, user_id, location_data) do
          :ok ->
            # Update participant activity
            update_participant_activity(session_id, user_id)
            
            # Update session activity
            Redis.update_session_activity(session_id)
            
            # Broadcast to other participants in the session
            broadcast_message = %{
              type: "location_update",
              data: Map.put(location_data, :user_id, user_id)
            }
            
            broadcast!(socket, "location_update", broadcast_message)
            
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
    
    # Update participant activity
    update_participant_activity(session_id, user_id)
    
    {:reply, {:ok, %{type: "pong", data: %{}}}, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    Logger.warning("Unhandled channel event: #{event} with payload: #{inspect(payload)}")
    {:reply, {:error, %{reason: "unknown_event"}}, socket}
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
    
    # Remove connection mapping
    Redis.delete_connection(user_id)
    
    # Note: We don't immediately remove from session participants
    # The cleanup worker will handle inactive participants
    
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
        now = DateTime.utc_now()
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
    case Redis.get_session_participants(session_id) do
      {:ok, user_ids} ->
        participants = get_participant_details(session_id, user_ids)
        push(socket, "initial_participants", %{participants: participants})
      
      {:error, _} ->
        Logger.warning("Could not fetch initial participants for session #{session_id}")
    end
    
    # Send current locations
    case Redis.get_session_locations(session_id) do
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

  defp get_participant_details(session_id, user_ids) do
    Participant.active_for_session(session_id)
    |> Repo.all()
    |> Enum.filter(fn p -> p.user_id in user_ids end)
    |> Enum.map(fn participant ->
      %{
        user_id: participant.user_id,
        display_name: participant.display_name,
        avatar_color: participant.avatar_color
      }
    end)
  end

  defp generate_connection_id do
    "conn_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end