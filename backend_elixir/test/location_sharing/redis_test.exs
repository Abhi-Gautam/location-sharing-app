defmodule LocationSharing.RedisTest do
  use ExUnit.Case

  alias LocationSharing.Redis

  setup do
    session_id = "test_session_#{System.unique_integer()}"
    user_id = "test_user_#{System.unique_integer()}"

    # Cleanup any existing test data
    on_exit(fn ->
      Redis.cleanup_session(session_id)
      Redis.delete_connection(user_id)
    end)

    {:ok, session_id: session_id, user_id: user_id}
  end

  describe "location operations" do
    test "stores and retrieves location data", %{session_id: session_id, user_id: user_id} do
      location_data = %{
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: "2025-01-15T10:30:00Z"
      }

      # Store location
      assert :ok = Redis.set_location(session_id, user_id, location_data)

      # Retrieve location
      assert {:ok, retrieved_data} = Redis.get_location(session_id, user_id)
      assert retrieved_data["lat"] == 37.7749
      assert retrieved_data["lng"] == -122.4194
      assert retrieved_data["accuracy"] == 5.0
      assert retrieved_data["timestamp"] == "2025-01-15T10:30:00Z"
    end

    test "returns error for non-existent location", %{session_id: session_id} do
      assert {:error, :not_found} = Redis.get_location(session_id, "nonexistent_user")
    end

    test "deletes location data", %{session_id: session_id, user_id: user_id} do
      location_data = %{lat: 37.7749, lng: -122.4194, accuracy: 5.0, timestamp: "2025-01-15T10:30:00Z"}
      
      # Store and then delete
      assert :ok = Redis.set_location(session_id, user_id, location_data)
      assert :ok = Redis.delete_location(session_id, user_id)
      
      # Verify deletion
      assert {:error, :not_found} = Redis.get_location(session_id, user_id)
    end

    test "retrieves session locations for multiple users", %{session_id: session_id} do
      user1 = "user1_#{System.unique_integer()}"
      user2 = "user2_#{System.unique_integer()}"
      
      # Add users to session
      Redis.add_session_participant(session_id, user1)
      Redis.add_session_participant(session_id, user2)
      
      # Store locations
      location1 = %{lat: 37.7749, lng: -122.4194, accuracy: 5.0, timestamp: "2025-01-15T10:30:00Z"}
      location2 = %{lat: 37.7849, lng: -122.4094, accuracy: 3.0, timestamp: "2025-01-15T10:31:00Z"}
      
      Redis.set_location(session_id, user1, location1)
      Redis.set_location(session_id, user2, location2)
      
      # Retrieve all locations
      assert {:ok, locations} = Redis.get_session_locations(session_id)
      assert length(locations) == 2
      
      user_ids = Enum.map(locations, & &1[:user_id])
      assert user1 in user_ids
      assert user2 in user_ids
      
      # Cleanup
      Redis.remove_session_participant(session_id, user1)
      Redis.remove_session_participant(session_id, user2)
    end
  end

  describe "session participant operations" do
    test "adds and removes session participants", %{session_id: session_id, user_id: user_id} do
      # Add participant
      assert :ok = Redis.add_session_participant(session_id, user_id)
      
      # Check participant exists
      assert {:ok, true} = Redis.is_session_participant?(session_id, user_id)
      
      # Get participant list
      assert {:ok, participants} = Redis.get_session_participants(session_id)
      assert user_id in participants
      
      # Get participant count
      assert {:ok, count} = Redis.get_session_participant_count(session_id)
      assert count >= 1
      
      # Remove participant
      assert :ok = Redis.remove_session_participant(session_id, user_id)
      
      # Verify removal
      assert {:ok, false} = Redis.is_session_participant?(session_id, user_id)
    end

    test "handles multiple participants", %{session_id: session_id} do
      user1 = "user1_#{System.unique_integer()}"
      user2 = "user2_#{System.unique_integer()}"
      user3 = "user3_#{System.unique_integer()}"
      
      # Add multiple participants
      Redis.add_session_participant(session_id, user1)
      Redis.add_session_participant(session_id, user2)
      Redis.add_session_participant(session_id, user3)
      
      # Check count
      assert {:ok, count} = Redis.get_session_participant_count(session_id)
      assert count == 3
      
      # Get all participants
      assert {:ok, participants} = Redis.get_session_participants(session_id)
      assert length(participants) == 3
      assert user1 in participants
      assert user2 in participants
      assert user3 in participants
      
      # Remove one participant
      Redis.remove_session_participant(session_id, user2)
      
      # Check updated count
      assert {:ok, count} = Redis.get_session_participant_count(session_id)
      assert count == 2
      
      # Cleanup
      Redis.remove_session_participant(session_id, user1)
      Redis.remove_session_participant(session_id, user3)
    end
  end

  describe "connection operations" do
    test "stores and retrieves connection mappings", %{user_id: user_id} do
      connection_id = "conn_#{System.unique_integer()}"
      
      # Set connection
      assert :ok = Redis.set_connection(user_id, connection_id)
      
      # Get connection
      assert {:ok, ^connection_id} = Redis.get_connection(user_id)
      
      # Delete connection
      assert :ok = Redis.delete_connection(user_id)
      
      # Verify deletion
      assert {:error, :not_found} = Redis.get_connection(user_id)
    end
  end

  describe "session activity operations" do
    test "tracks session activity", %{session_id: session_id} do
      # Update activity
      assert :ok = Redis.update_session_activity(session_id)
      
      # Get activity timestamp
      assert {:ok, timestamp} = Redis.get_session_activity(session_id)
      assert %DateTime{} = timestamp
      
      # Check it's recent (within last minute)
      now = DateTime.utc_now()
      diff = DateTime.diff(now, timestamp)
      assert diff < 60
    end

    test "returns error for non-existent session activity" do
      fake_session_id = "nonexistent_session"
      assert {:error, :not_found} = Redis.get_session_activity(fake_session_id)
    end
  end

  describe "cleanup operations" do
    test "cleans up all session data", %{session_id: session_id} do
      user1 = "cleanup_user1_#{System.unique_integer()}"
      user2 = "cleanup_user2_#{System.unique_integer()}"
      
      # Set up session data
      Redis.add_session_participant(session_id, user1)
      Redis.add_session_participant(session_id, user2)
      Redis.set_location(session_id, user1, %{lat: 37.7749, lng: -122.4194, accuracy: 5.0, timestamp: "2025-01-15T10:30:00Z"})
      Redis.set_location(session_id, user2, %{lat: 37.7849, lng: -122.4094, accuracy: 3.0, timestamp: "2025-01-15T10:31:00Z"})
      Redis.set_connection(user1, "conn1")
      Redis.set_connection(user2, "conn2")
      Redis.update_session_activity(session_id)
      
      # Verify data exists
      assert {:ok, participants} = Redis.get_session_participants(session_id)
      assert length(participants) == 2
      
      # Cleanup session
      assert :ok = Redis.cleanup_session(session_id)
      
      # Verify cleanup
      assert {:ok, []} = Redis.get_session_participants(session_id)
      assert {:error, :not_found} = Redis.get_location(session_id, user1)
      assert {:error, :not_found} = Redis.get_location(session_id, user2)
      assert {:error, :not_found} = Redis.get_connection(user1)
      assert {:error, :not_found} = Redis.get_connection(user2)
    end
  end
end