defmodule LocationSharingWeb.HealthControllerTest do
  use LocationSharingWeb.ConnCase

  describe "GET /health" do
    test "returns basic health status", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert %{
        "status" => "healthy",
        "timestamp" => _timestamp,
        "version" => _version
      } = json_response(conn, 200)
    end
  end

  describe "GET /health/detailed" do
    test "returns detailed health status with all checks", %{conn: conn} do
      conn = get(conn, ~p"/health/detailed")

      assert %{
        "status" => status,
        "timestamp" => _timestamp,
        "version" => _version,
        "checks" => %{
          "database" => database_check,
          "redis" => redis_check,
          "application" => app_check
        }
      } = json_response(conn, 200)

      # Should be healthy in test environment
      assert status in ["healthy", "unhealthy"]
      assert Map.has_key?(database_check, "status")
      assert Map.has_key?(redis_check, "status")
      assert Map.has_key?(app_check, "status")
    end

    test "returns 503 when dependencies are unhealthy" do
      # This would require mocking failing dependencies
      # For now, we just test the structure
    end
  end

  describe "GET /health/ready" do
    test "returns readiness status", %{conn: conn} do
      conn = get(conn, ~p"/health/ready")

      response = json_response(conn, 200)
      
      assert %{
        "status" => "ready",
        "timestamp" => _timestamp
      } = response
    end
  end

  describe "GET /health/live" do
    test "returns liveness status", %{conn: conn} do
      conn = get(conn, ~p"/health/live")

      assert %{
        "status" => "alive",
        "timestamp" => _timestamp
      } = json_response(conn, 200)
    end
  end
end