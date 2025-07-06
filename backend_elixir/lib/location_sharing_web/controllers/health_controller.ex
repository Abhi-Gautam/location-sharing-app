defmodule LocationSharingWeb.HealthController do
  @moduledoc """
  Health check endpoints for monitoring and load balancer integration.
  """

  use LocationSharingWeb, :controller

  alias LocationSharing.Repo

  require Logger

  @doc """
  Basic health check endpoint.

  Returns 200 OK if the application is running.
  """
  def index(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:location_sharing, :vsn) || "unknown"
    })
  end

  @doc """
  Detailed health check with dependency status.

  Checks connectivity to:
  - PostgreSQL database
  - Application processes (BEAM coordination)
  """
  def detailed(conn, _params) do
    checks = %{
      database: check_database(),
      application: check_application()
    }

    overall_status = determine_overall_status(checks)
    status_code = if overall_status == "healthy", do: :ok, else: :service_unavailable

    response = %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      version: Application.spec(:location_sharing, :vsn) || "unknown",
      checks: checks
    }

    conn
    |> put_status(status_code)
    |> json(response)
  end

  @doc """
  Readiness check for Kubernetes deployments.

  Returns 200 when the application is ready to serve traffic.
  """
  def ready(conn, _params) do
    case check_readiness() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ready", timestamp: DateTime.utc_now()})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "not_ready", reason: reason, timestamp: DateTime.utc_now()})
    end
  end

  @doc """
  Liveness check for Kubernetes deployments.

  Returns 200 when the application is alive.
  """
  def live(conn, _params) do
    # Simple liveness check - if we can respond, we're alive
    conn
    |> put_status(:ok)
    |> json(%{status: "alive", timestamp: DateTime.utc_now()})
  end

  # Private helper functions

  defp check_database do
    try do
      case Repo.query("SELECT 1", []) do
        {:ok, _} ->
          %{status: "healthy", response_time_ms: measure_db_response_time()}

        {:error, reason} ->
          Logger.warning("Database health check failed: #{inspect(reason)}")
          %{status: "unhealthy", error: inspect(reason)}
      end
    rescue
      error ->
        Logger.error("Database health check error: #{inspect(error)}")
        %{status: "unhealthy", error: inspect(error)}
    end
  end


  defp check_application do
    try do
      # Check if critical processes are running
      critical_processes = [
        LocationSharing.Repo,
        LocationSharingWeb.Endpoint,
        LocationSharing.Sessions.Supervisor,
        LocationSharing.Sessions.CleanupWorker
      ]

      process_statuses = Enum.map(critical_processes, fn process_name ->
        case Process.whereis(process_name) do
          nil -> {process_name, "not_running"}
          pid when is_pid(pid) -> {process_name, "running"}
        end
      end)

      unhealthy_processes = Enum.filter(process_statuses, fn {_, status} -> status != "running" end)

      if Enum.empty?(unhealthy_processes) do
        %{status: "healthy", processes: Map.new(process_statuses)}
      else
        %{
          status: "unhealthy", 
          processes: Map.new(process_statuses),
          unhealthy_processes: Enum.map(unhealthy_processes, fn {name, _} -> name end)
        }
      end
    rescue
      error ->
        Logger.error("Application health check error: #{inspect(error)}")
        %{status: "unhealthy", error: inspect(error)}
    end
  end

  defp measure_db_response_time do
    start_time = System.monotonic_time(:millisecond)
    
    case Repo.query("SELECT 1", []) do
      {:ok, _} -> System.monotonic_time(:millisecond) - start_time
      {:error, _} -> nil
    end
  end

  defp determine_overall_status(checks) do
    statuses = Enum.map(checks, fn {_, check} -> check.status end)
    
    if Enum.all?(statuses, &(&1 == "healthy")) do
      "healthy"
    else
      "unhealthy"
    end
  end

  defp check_readiness do
    # Application is ready when database and critical processes are available
    with %{status: "healthy"} <- check_database(),
         %{status: "healthy"} <- check_application() do
      :ok
    else
      %{status: "unhealthy", error: error} -> {:error, error}
      _ -> {:error, "dependency_not_ready"}
    end
  end
end