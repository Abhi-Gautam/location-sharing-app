defmodule LocationSharingWeb.UserSocket do
  @moduledoc """
  WebSocket connection handler for location sharing.

  Authenticates users via JWT tokens and manages channel subscriptions.
  """

  use Phoenix.Socket

  require Logger

  alias LocationSharing.Guardian

  # Channels
  channel "location:*", LocationSharingWeb.LocationChannel
  channel "session:*", LocationSharingWeb.LocationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    Logger.debug("WebSocket connection attempt with token")
    
    case Guardian.validate_websocket_token(token) do
      {:ok, %{participant_id: participant_id, session_id: session_id, user_id: user_id}} ->
        Logger.info("WebSocket authenticated for user #{user_id} in session #{session_id}")
        
        socket = 
          socket
          |> assign(:participant_id, participant_id)
          |> assign(:session_id, session_id)
          |> assign(:user_id, user_id)
          |> assign(:authenticated, true)
        
        {:ok, socket}

      {:error, reason} ->
        Logger.warning("WebSocket authentication failed: #{inspect(reason)}")
        :error
    end
  end

  @impl true
  def connect(_params, _socket, _connect_info) do
    Logger.warning("WebSocket connection attempted without token")
    :error
  end

  @impl true
  def id(socket) do
    # Use user_id for socket identification
    # This allows us to close all connections for a user if needed
    case socket.assigns do
      %{user_id: user_id} -> "user_socket:#{user_id}"
      _ -> nil
    end
  end

  @impl true
  def handle_params(params, socket) do
    Logger.debug("WebSocket params: #{inspect(params)}")
    {:ok, socket}
  end
end