defmodule LocationSharingWeb.LocationChannelTest do
  use LocationSharingWeb.ChannelCase

  import LocationSharing.Factory

  alias LocationSharing.Guardian
  alias LocationSharingWeb.{UserSocket, LocationChannel}

  setup do
    session = insert(:session)
    participant = insert(:participant, session_id: session.id)

    {:ok, token} = Guardian.create_websocket_token(participant)

    socket = 
      socket(UserSocket, "user_socket:#{participant.user_id}", %{
        participant_id: participant.id,
        session_id: session.id,
        user_id: participant.user_id,
        authenticated: true
      })

    {:ok, socket: socket, session: session, participant: participant, token: token}
  end

  describe "joining location channel" do
    test "successfully joins with valid session", %{socket: socket, session: session} do
      {:ok, response, _socket} = subscribe_and_join(socket, LocationChannel, "location:#{session.id}")

      assert response == %{status: "joined", session_id: session.id}
    end

    test "rejects join for different session", %{socket: socket} do
      different_session = insert(:session)

      assert {:error, %{reason: "unauthorized"}} = 
        subscribe_and_join(socket, LocationChannel, "location:#{different_session.id}")
    end

    test "rejects join for unauthenticated socket" do
      unauthenticated_socket = socket(UserSocket, "user_socket:anonymous", %{})

      session = insert(:session)

      assert {:error, %{reason: "unauthenticated"}} = 
        subscribe_and_join(unauthenticated_socket, LocationChannel, "location:#{session.id}")
    end

    test "rejects join for inactive session" do
      inactive_session = insert(:session, is_active: false)
      participant = insert(:participant, session_id: inactive_session.id)

      # Create socket for inactive session
      socket = socket(UserSocket, "user_socket:#{participant.user_id}", %{
        participant_id: participant.id,
        session_id: inactive_session.id,
        user_id: participant.user_id,
        authenticated: true
      })

      assert {:error, %{reason: "session_ended"}} = 
        subscribe_and_join(socket, LocationChannel, "location:#{inactive_session.id}")
    end
  end

  describe "location updates" do
    setup %{socket: socket, session: session} do
      {:ok, _response, socket} = subscribe_and_join(socket, LocationChannel, "location:#{session.id}")
      {:ok, socket: socket}
    end

    test "handles valid location update", %{socket: socket, participant: participant} do
      location_data = %{
        "lat" => 37.7749,
        "lng" => -122.4194,
        "accuracy" => 5.0,
        "timestamp" => "2025-01-15T10:30:00Z"
      }

      push(socket, "location_update", location_data)

      # Should push location update to channel participants
      assert_push "location_update", %{
        type: "location_update",
        data: %{
          user_id: user_id,
          lat: 37.7749,
          lng: -122.4194,
          accuracy: 5.0,
          timestamp: "2025-01-15T10:30:00Z"
        }
      }
      
      assert user_id == participant.user_id
    end

    test "rejects invalid latitude", %{socket: socket} do
      location_data = %{
        "lat" => 91.0,  # Invalid latitude
        "lng" => -122.4194,
        "accuracy" => 5.0,
        "timestamp" => "2025-01-15T10:30:00Z"
      }

      ref = push(socket, "location_update", location_data)
      assert_reply ref, :error, %{reason: "invalid_location_data"}
    end

    test "rejects invalid longitude", %{socket: socket} do
      location_data = %{
        "lat" => 37.7749,
        "lng" => -181.0,  # Invalid longitude
        "accuracy" => 5.0,
        "timestamp" => "2025-01-15T10:30:00Z"
      }

      ref = push(socket, "location_update", location_data)
      assert_reply ref, :error, %{reason: "invalid_location_data"}
    end
  end

  describe "ping/pong" do
    setup %{socket: socket, session: session} do
      {:ok, _response, socket} = subscribe_and_join(socket, LocationChannel, "location:#{session.id}")
      {:ok, socket: socket}
    end

    test "responds to ping with pong", %{socket: socket} do
      ref = push(socket, "ping", %{})
      assert_reply ref, :ok, %{type: "pong", data: %{}}
    end
  end

  describe "unknown events" do
    setup %{socket: socket, session: session} do
      {:ok, _response, socket} = subscribe_and_join(socket, LocationChannel, "location:#{session.id}")
      {:ok, socket: socket}
    end

    test "rejects unknown events", %{socket: socket} do
      ref = push(socket, "unknown_event", %{"data" => "test"})
      assert_reply ref, :error, %{reason: "unknown_event"}
    end
  end
end