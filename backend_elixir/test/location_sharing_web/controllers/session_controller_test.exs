defmodule LocationSharingWeb.SessionControllerTest do
  use LocationSharingWeb.ConnCase

  import LocationSharing.Factory

  alias LocationSharing.{Repo, Redis}
  alias LocationSharing.Sessions.Session

  describe "POST /api/sessions" do
    test "creates session with valid parameters", %{conn: conn} do
      params = %{
        "name" => "Test Session",
        "expires_in_minutes" => 120
      }

      conn = post(conn, ~p"/api/sessions", params)

      assert %{
        "session_id" => session_id,
        "join_link" => join_link,
        "expires_at" => expires_at,
        "name" => "Test Session"
      } = json_response(conn, 201)

      assert is_binary(session_id)
      assert String.contains?(join_link, session_id)
      assert is_binary(expires_at)

      # Verify session was created in database
      session = Repo.get(Session, session_id)
      assert session
      assert session.name == "Test Session"
      assert session.is_active
    end

    test "creates session with default values", %{conn: conn} do
      conn = post(conn, ~p"/api/sessions", %{})

      assert %{
        "session_id" => session_id,
        "join_link" => _join_link,
        "expires_at" => _expires_at,
        "name" => nil
      } = json_response(conn, 201)

      # Verify session was created in database
      session = Repo.get(Session, session_id)
      assert session
      assert session.name == nil
      assert session.is_active
    end

    test "handles invalid expires_in_minutes", %{conn: conn} do
      params = %{
        "name" => "Test Session",
        "expires_in_minutes" => "invalid"
      }

      conn = post(conn, ~p"/api/sessions", params)

      assert %{
        "session_id" => _session_id,
        "join_link" => _join_link,
        "expires_at" => _expires_at,
        "name" => "Test Session"
      } = json_response(conn, 201)
    end
  end

  describe "GET /api/sessions/:id" do
    test "returns session details for valid session", %{conn: conn} do
      session = insert(:session, name: "Test Session")
      Redis.update_session_activity(session.id)

      conn = get(conn, ~p"/api/sessions/#{session.id}")

      assert %{
        "id" => session_id,
        "name" => "Test Session",
        "created_at" => _created_at,
        "expires_at" => _expires_at,
        "participant_count" => 0,
        "is_active" => true
      } = json_response(conn, 200)

      assert session_id == session.id
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/sessions/#{fake_id}")

      assert %{"error" => "Session not found"} = json_response(conn, 404)
    end

    test "returns 404 for inactive session", %{conn: conn} do
      session = insert(:session, is_active: false)

      conn = get(conn, ~p"/api/sessions/#{session.id}")

      assert %{"error" => "Session has ended"} = json_response(conn, 404)
    end

    test "returns 404 for expired session", %{conn: conn} do
      expires_at = DateTime.add(DateTime.utc_now(), -3600, :second)
      session = insert(:session, expires_at: expires_at)

      conn = get(conn, ~p"/api/sessions/#{session.id}")

      assert %{"error" => "Session has expired"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/sessions/:id" do
    test "ends active session", %{conn: conn} do
      session = insert(:session)

      conn = delete(conn, ~p"/api/sessions/#{session.id}")

      assert %{"success" => true} = json_response(conn, 200)

      # Verify session was marked inactive
      updated_session = Repo.get(Session, session.id)
      refute updated_session.is_active
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, ~p"/api/sessions/#{fake_id}")

      assert %{"error" => "Session not found"} = json_response(conn, 404)
    end

    test "returns 404 for already ended session", %{conn: conn} do
      session = insert(:session, is_active: false)

      conn = delete(conn, ~p"/api/sessions/#{session.id}")

      assert %{"error" => "Session already ended"} = json_response(conn, 404)
    end
  end
end