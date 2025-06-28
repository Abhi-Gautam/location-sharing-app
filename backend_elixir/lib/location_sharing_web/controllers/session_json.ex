defmodule LocationSharingWeb.SessionJSON do
  @moduledoc """
  JSON serialization for session data.
  """

  alias LocationSharing.Sessions.Session

  @doc """
  Renders a session for creation response.
  """
  def create(%{session: session, join_link: join_link}) do
    %{
      session_id: session.id,
      join_link: join_link,
      expires_at: session.expires_at,
      name: session.name
    }
  end

  @doc """
  Renders session details.
  """
  def show(%{session: session, participant_count: participant_count}) do
    %{
      id: session.id,
      name: session.name,
      created_at: session.created_at,
      expires_at: session.expires_at,
      participant_count: participant_count,
      is_active: session.is_active
    }
  end

  @doc """
  Renders session deletion response.
  """
  def delete(%{}) do
    %{success: true}
  end

  @doc """
  Renders error response.
  """
  def error(%{error: error}) when is_binary(error) do
    %{error: error}
  end

  def error(%{error: error, details: details}) do
    %{error: error, details: details}
  end

  @doc """
  Renders a basic session without associations.
  """
  def data(%Session{} = session) do
    %{
      id: session.id,
      name: session.name,
      created_at: session.created_at,
      expires_at: session.expires_at,
      is_active: session.is_active,
      last_activity: session.last_activity
    }
  end
end