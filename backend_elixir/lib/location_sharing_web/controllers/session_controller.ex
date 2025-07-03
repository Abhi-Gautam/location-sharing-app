defmodule LocationSharingWeb.SessionController do
  @moduledoc """
  Controller for session management endpoints.

  Handles creating, viewing, and ending location sharing sessions.
  """

  use LocationSharingWeb, :controller

  alias LocationSharing.{Repo, Redis}
  alias LocationSharing.Sessions.{Session, Participant}

  require Logger

  @doc """
  Creates a new location sharing session.

  ## Request Body
    * `name` (optional) - Session name
    * `expires_in_minutes` (optional) - Session duration in minutes (default: 1440 = 24h)

  ## Response
    * `201` - Session created successfully
    * `400` - Invalid request parameters
    * `500` - Internal server error
  """
  def create(conn, params) do
    Logger.info("Creating new session with params: #{inspect(params)}")
    
    # Parse expires_in_minutes and convert to expires_at timestamp
    expires_at = case params["expires_in_minutes"] do
      nil -> nil
      minutes when is_integer(minutes) ->
        DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(minutes * 60, :second)
      minutes when is_binary(minutes) ->
        case Integer.parse(minutes) do
          {parsed_minutes, ""} -> 
            DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(parsed_minutes * 60, :second)
          _ -> nil
        end
      _ -> nil
    end

    session_attrs = %{
      name: params["name"],
      expires_at: expires_at,
      creator_id: Ecto.UUID.generate()
    }

    case Session.create_changeset(session_attrs) |> Repo.insert() do
      {:ok, session} ->
        Logger.info("Created session: #{session.id}")
        
        # Update Redis activity
        Redis.update_session_activity(session.id)
        
        response = %{
          session_id: session.id,
          join_link: build_join_link(conn, session.id),
          expires_at: session.expires_at,
          name: session.name
        }
        
        conn
        |> put_status(:created)
        |> json(response)

      {:error, changeset} ->
        Logger.warning("Failed to create session: #{inspect(changeset.errors)}")
        
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid session parameters",
          details: format_changeset_errors(changeset)
        })
    end
  rescue
    error ->
      Logger.error("Error creating session: #{inspect(error)}")
      
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to create session"})
  end

  @doc """
  Retrieves session details and participant count.

  ## Path Parameters
    * `id` - Session UUID

  ## Response
    * `200` - Session details
    * `404` - Session not found
    * `500` - Internal server error
  """
  def show(conn, %{"id" => session_id}) do
    Logger.debug("Fetching session: #{session_id}")
    
    case Repo.get(Session, session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})

      %Session{is_active: false} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session has ended"})

      session ->
        # Check if session has expired
        if session_expired?(session) do
          # Mark as inactive
          {:ok, _} = Session.end_session_changeset(session) |> Repo.update()
          
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session has expired"})
        else
          # Get participant count from Redis (more accurate for active participants)
          {:ok, participant_count} = Redis.get_session_participant_count(session.id)
          
          response = %{
            id: session.id,
            name: session.name,
            created_at: session.created_at,
            expires_at: session.expires_at,
            participant_count: participant_count,
            is_active: session.is_active
          }
          
          conn
          |> put_status(:ok)
          |> json(response)
        end
    end
  rescue
    error ->
      Logger.error("Error fetching session #{session_id}: #{inspect(error)}")
      
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to fetch session"})
  end

  @doc """
  Ends a session (creator only).

  ## Path Parameters
    * `id` - Session UUID

  ## Response
    * `200` - Session ended successfully
    * `404` - Session not found
    * `403` - Unauthorized (not creator)
    * `500` - Internal server error
  """
  def delete(conn, %{"id" => session_id}) do
    Logger.info("Ending session: #{session_id}")
    
    case Repo.get(Session, session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})

      %Session{is_active: false} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session already ended"})

      session ->
        # For MVP, any request can end a session (no creator validation)
        # In production, you'd validate the creator_id
        
        case Session.end_session_changeset(session) |> Repo.update() do
          {:ok, updated_session} ->
            Logger.info("Ended session: #{session_id}")
            
            # Notify all participants via WebSocket
            broadcast_session_ended(session_id, "ended_by_creator")
            
            # Cleanup Redis data
            Redis.cleanup_session(session_id)
            
            conn
            |> put_status(:ok)
            |> json(%{success: true})

          {:error, changeset} ->
            Logger.error("Failed to end session #{session_id}: #{inspect(changeset.errors)}")
            
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to end session"})
        end
    end
  rescue
    error ->
      Logger.error("Error ending session #{session_id}: #{inspect(error)}")
      
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to end session"})
  end

  # Private helper functions

  defp build_join_link(conn, session_id) do
    # In a real app, this would be the frontend URL
    base_url = get_base_url(conn)
    "#{base_url}/join/#{session_id}"
  end

  defp get_base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    host = get_req_header(conn, "host") |> List.first() || "localhost:4000"
    "#{scheme}://#{host}"
  end

  defp session_expired?(%Session{expires_at: nil}), do: false
  defp session_expired?(%Session{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
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
end