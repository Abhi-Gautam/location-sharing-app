defmodule LocationSharingWeb.ParticipantController do
  @moduledoc """
  Controller for participant management endpoints.

  Handles joining sessions, leaving sessions, and listing participants.
  """

  use LocationSharingWeb, :controller

  alias LocationSharing.{Repo, Redis, Guardian}
  alias LocationSharing.Sessions.{Session, Participant}

  require Logger

  @max_participants_per_session 50

  @doc """
  Joins a participant to a session.

  ## Path Parameters
    * `session_id` - Session UUID

  ## Request Body
    * `display_name` - Participant's display name (required)
    * `avatar_color` - Hex color code (optional)

  ## Response
    * `201` - Successfully joined session
    * `400` - Invalid request parameters
    * `404` - Session not found
    * `409` - Session full or name conflict
    * `500` - Internal server error
  """
  def join(conn, %{"session_id" => session_id} = params) do
    Logger.info("User joining session #{session_id} with params: #{inspect(params)}")
    
    # Validate session exists and is active
    case validate_session(session_id) do
      {:ok, session} ->
        # Check participant limit
        case Redis.get_session_participant_count(session_id) do
          {:ok, count} when count >= @max_participants_per_session ->
            conn
            |> put_status(:conflict)
            |> json(%{error: "Session is full (maximum #{@max_participants_per_session} participants)"})

          {:ok, _count} ->
            create_participant(conn, session, params)

          {:error, _} ->
            # If Redis fails, continue with database check
            create_participant(conn, session, params)
        end

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  rescue
    error ->
      Logger.error("Error joining session #{session_id}: #{inspect(error)}")
      
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to join session"})
  end

  @doc """
  Removes a participant from a session.

  ## Path Parameters
    * `session_id` - Session UUID
    * `user_id` - User ID to remove

  ## Response
    * `200` - Successfully left session
    * `404` - Session or participant not found
    * `500` - Internal server error
  """
  def leave(conn, %{"session_id" => session_id, "user_id" => user_id}) do
    Logger.info("User #{user_id} leaving session #{session_id}")
    
    case find_participant(session_id, user_id) do
      {:ok, participant} ->
        case Participant.leave_changeset(participant) |> Repo.update() do
          {:ok, _updated_participant} ->
            Logger.info("User #{user_id} left session #{session_id}")
            
            # Remove from Redis
            Redis.remove_session_participant(session_id, user_id)
            
            # Broadcast to other participants
            broadcast_participant_left(session_id, user_id)
            
            # Update session activity
            Redis.update_session_activity(session_id)
            
            conn
            |> put_status(:ok)
            |> json(%{success: true})

          {:error, changeset} ->
            Logger.error("Failed to remove participant #{user_id} from session #{session_id}: #{inspect(changeset.errors)}")
            
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to leave session"})
        end

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  rescue
    error ->
      Logger.error("Error leaving session #{session_id} for user #{user_id}: #{inspect(error)}")
      
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to leave session"})
  end

  @doc """
  Lists all active participants in a session.

  ## Path Parameters
    * `session_id` - Session UUID

  ## Response
    * `200` - List of participants
    * `404` - Session not found
    * `500` - Internal server error
  """
  def list(conn, %{"session_id" => session_id}) do
    Logger.debug("Listing participants for session #{session_id}")
    
    case validate_session(session_id) do
      {:ok, _session} ->
        participants = 
          Participant.active_for_session(session_id)
          |> Repo.all()
          |> Enum.map(&format_participant/1)
        
        response = %{participants: participants}
        
        conn
        |> put_status(:ok)
        |> json(response)

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  rescue
    error ->
      Logger.error("Error listing participants for session #{session_id}: #{inspect(error)}")
      
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to list participants"})
  end

  # Private helper functions

  defp validate_session(session_id) do
    case Repo.get(Session, session_id) do
      nil ->
        {:error, "Session not found"}

      %Session{is_active: false} ->
        {:error, "Session has ended"}

      session ->
        if session_expired?(session) do
          # Mark as inactive
          {:ok, _} = Session.end_session_changeset(session) |> Repo.update()
          {:error, "Session has expired"}
        else
          {:ok, session}
        end
    end
  end

  defp create_participant(conn, session, params) do
    # Generate unique user ID
    user_id = Participant.generate_user_id()
    
    participant_attrs = %{
      session_id: session.id,
      user_id: user_id,
      display_name: params["display_name"],
      avatar_color: params["avatar_color"]
    }

    case Participant.join_changeset(participant_attrs) |> Repo.insert() do
      {:ok, participant} ->
        Logger.info("User #{user_id} joined session #{session.id} as '#{participant.display_name}'")
        
        # Add to Redis
        Redis.add_session_participant(session.id, user_id)
        
        # Generate JWT token for WebSocket authentication
        case Guardian.create_websocket_token(participant) do
          {:ok, token} ->
            # Broadcast to other participants
            broadcast_participant_joined(session.id, participant)
            
            # Update session activity
            Redis.update_session_activity(session.id)
            
            response = %{
              user_id: user_id,
              websocket_token: token,
              websocket_url: build_websocket_url(conn)
            }
            
            conn
            |> put_status(:created)
            |> json(response)

          {:error, reason} ->
            Logger.error("Failed to generate token for participant #{user_id}: #{inspect(reason)}")
            
            # Clean up participant if token generation fails
            Repo.delete(participant)
            
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to generate authentication token"})
        end

      {:error, changeset} ->
        Logger.warning("Failed to create participant: #{inspect(changeset.errors)}")
        
        error_message = case changeset.errors do
          [display_name: {_, [constraint: :unique, constraint_name: _]}] ->
            "Display name is already taken in this session"
          
          _ ->
            "Invalid participant parameters"
        end
        
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: error_message,
          details: format_changeset_errors(changeset)
        })
    end
  end

  defp find_participant(session_id, user_id) do
    case Repo.one(Participant.by_session_and_user(session_id, user_id)) do
      nil ->
        {:error, "Participant not found"}
      
      %Participant{is_active: false} ->
        {:error, "Participant has already left"}
      
      participant ->
        {:ok, participant}
    end
  end

  defp session_expired?(%Session{expires_at: nil}), do: false
  defp session_expired?(%Session{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp format_participant(participant) do
    %{
      user_id: participant.user_id,
      display_name: participant.display_name,
      avatar_color: participant.avatar_color,
      last_seen: participant.last_seen,
      is_active: participant.is_active
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp build_websocket_url(conn) do
    scheme = if conn.scheme == :https, do: "wss", else: "ws"
    host = get_req_header(conn, "host") |> List.first() || "localhost:4000"
    "#{scheme}://#{host}/socket/websocket"
  end

  defp broadcast_participant_joined(session_id, participant) do
    message = %{
      type: "participant_joined",
      data: %{
        user_id: participant.user_id,
        display_name: participant.display_name,
        avatar_color: participant.avatar_color
      }
    }
    
    Phoenix.PubSub.broadcast(
      LocationSharing.PubSub,
      "session:#{session_id}",
      {:participant_joined, message}
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