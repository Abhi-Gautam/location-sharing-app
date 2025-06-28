defmodule LocationSharingWeb.ParticipantControllerTest do
  use LocationSharingWeb.ConnCase

  import LocationSharing.Factory

  alias LocationSharing.{Repo, Redis}
  alias LocationSharing.Sessions.Participant

  describe "POST /api/sessions/:session_id/join" do
    test "joins session with valid parameters", %{conn: conn} do
      session = insert(:session)
      
      params = %{
        "display_name" => "John Doe",
        "avatar_color" => "#FF5733"
      }

      conn = post(conn, ~p"/api/sessions/#{session.id}/join", params)

      assert %{
        "user_id" => user_id,
        "websocket_token" => token,
        "websocket_url" => websocket_url
      } = json_response(conn, 201)

      assert is_binary(user_id)
      assert String.starts_with?(user_id, "user_")
      assert is_binary(token)
      assert String.contains?(websocket_url, "websocket")

      # Verify participant was created in database
      participant = Repo.get_by(Participant, user_id: user_id, session_id: session.id)
      assert participant
      assert participant.display_name == "John Doe"
      assert participant.avatar_color == "#FF5733"
      assert participant.is_active
    end

    test "joins session with default avatar color", %{conn: conn} do
      session = insert(:session)
      
      params = %{
        "display_name" => "Jane Doe"
      }

      conn = post(conn, ~p"/api/sessions/#{session.id}/join", params)

      assert %{
        "user_id" => user_id,
        "websocket_token" => _token,
        "websocket_url" => _websocket_url
      } = json_response(conn, 201)

      # Verify participant has a valid avatar color
      participant = Repo.get_by(Participant, user_id: user_id, session_id: session.id)
      assert participant
      assert participant.display_name == "Jane Doe"
      assert String.match?(participant.avatar_color, ~r/^#[0-9A-Fa-f]{6}$/)
    end

    test "returns 400 for missing display name", %{conn: conn} do
      session = insert(:session)
      
      params = %{
        "avatar_color" => "#FF5733"
      }

      conn = post(conn, ~p"/api/sessions/#{session.id}/join", params)

      assert %{
        "error" => "Invalid participant parameters",
        "details" => details
      } = json_response(conn, 400)

      assert Map.has_key?(details, "display_name")
    end

    test "returns 400 for invalid avatar color", %{conn: conn} do
      session = insert(:session)
      
      params = %{
        "display_name" => "John Doe",
        "avatar_color" => "invalid-color"
      }

      conn = post(conn, ~p"/api/sessions/#{session.id}/join", params)

      assert %{
        "error" => "Invalid participant parameters",
        "details" => details
      } = json_response(conn, 400)

      assert Map.has_key?(details, "avatar_color")
    end

    test "returns 400 for duplicate display name", %{conn: conn} do
      session = insert(:session)
      _existing_participant = insert(:participant, session: session, display_name: "John Doe")
      
      params = %{
        "display_name" => "John Doe",
        "avatar_color" => "#FF5733"
      }

      conn = post(conn, ~p"/api/sessions/#{session.id}/join", params)

      assert %{
        "error" => "Display name is already taken in this session"
      } = json_response(conn, 400)
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      
      params = %{
        "display_name" => "John Doe"
      }

      conn = post(conn, ~p"/api/sessions/#{fake_id}/join", params)

      assert %{"error" => "Session not found"} = json_response(conn, 404)
    end

    test "returns 404 for inactive session", %{conn: conn} do
      session = insert(:session, is_active: false)
      
      params = %{
        "display_name" => "John Doe"
      }

      conn = post(conn, ~p"/api/sessions/#{session.id}/join", params)

      assert %{"error" => "Session has ended"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/sessions/:session_id/participants/:user_id" do
    test "removes participant from session", %{conn: conn} do
      session = insert(:session)
      participant = insert(:participant, session: session)

      conn = delete(conn, ~p"/api/sessions/#{session.id}/participants/#{participant.user_id}")

      assert %{"success" => true} = json_response(conn, 200)

      # Verify participant was marked inactive
      updated_participant = Repo.get(Participant, participant.id)
      refute updated_participant.is_active
    end

    test "returns 404 for non-existent participant", %{conn: conn} do
      session = insert(:session)
      fake_user_id = "user_nonexistent"

      conn = delete(conn, ~p"/api/sessions/#{session.id}/participants/#{fake_user_id}")

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end

    test "returns 404 for already inactive participant", %{conn: conn} do
      session = insert(:session)
      participant = insert(:participant, session: session, is_active: false)

      conn = delete(conn, ~p"/api/sessions/#{session.id}/participants/#{participant.user_id}")

      assert %{"error" => "Participant has already left"} = json_response(conn, 404)
    end
  end

  describe "GET /api/sessions/:session_id/participants" do
    test "lists active participants in session", %{conn: conn} do
      session = insert(:session)
      participant1 = insert(:participant, session: session, display_name: "Alice")
      participant2 = insert(:participant, session: session, display_name: "Bob")
      _inactive_participant = insert(:participant, session: session, display_name: "Charlie", is_active: false)

      conn = get(conn, ~p"/api/sessions/#{session.id}/participants")

      assert %{
        "participants" => participants
      } = json_response(conn, 200)

      assert length(participants) == 2
      
      participant_names = Enum.map(participants, & &1["display_name"])
      assert "Alice" in participant_names
      assert "Bob" in participant_names
      refute "Charlie" in participant_names

      # Verify participant structure
      alice = Enum.find(participants, &(&1["display_name"] == "Alice"))
      assert alice["user_id"] == participant1.user_id
      assert alice["avatar_color"] == participant1.avatar_color
      assert alice["is_active"] == true
    end

    test "returns empty list for session with no participants", %{conn: conn} do
      session = insert(:session)

      conn = get(conn, ~p"/api/sessions/#{session.id}/participants")

      assert %{
        "participants" => []
      } = json_response(conn, 200)
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/sessions/#{fake_id}/participants")

      assert %{"error" => "Session not found"} = json_response(conn, 404)
    end

    test "returns 404 for inactive session", %{conn: conn} do
      session = insert(:session, is_active: false)

      conn = get(conn, ~p"/api/sessions/#{session.id}/participants")

      assert %{"error" => "Session has ended"} = json_response(conn, 404)
    end
  end
end