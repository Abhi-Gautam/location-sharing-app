defmodule LocationSharingWeb.ParticipantJSON do
  @moduledoc """
  JSON serialization for participant data.
  """

  alias LocationSharing.Sessions.Participant

  @doc """
  Renders join response with WebSocket credentials.
  """
  def join(%{user_id: user_id, websocket_token: token, websocket_url: url}) do
    %{
      user_id: user_id,
      websocket_token: token,
      websocket_url: url
    }
  end

  @doc """
  Renders leave response.
  """
  def leave(%{}) do
    %{success: true}
  end

  @doc """
  Renders participants list.
  """
  def index(%{participants: participants}) do
    %{
      participants: for(participant <- participants, do: data(participant))
    }
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
  Renders a single participant.
  """
  def data(%Participant{} = participant) do
    %{
      user_id: participant.user_id,
      display_name: participant.display_name,
      avatar_color: participant.avatar_color,
      last_seen: participant.last_seen,
      is_active: participant.is_active
    }
  end

  def data(%{} = participant) do
    %{
      user_id: participant.user_id,
      display_name: participant.display_name,
      avatar_color: participant.avatar_color,
      last_seen: participant.last_seen,
      is_active: participant.is_active
    }
  end
end