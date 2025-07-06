defmodule LocationSharing.PromEx do
  @moduledoc """
  PromEx metrics configuration for Location Sharing Elixir backend.
  
  This module provides comprehensive Prometheus metrics for monitoring the BEAM-based
  coordination system, providing equivalent metrics to the Rust backend for comparison.
  """

  use PromEx, otp_app: :location_sharing

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # Core BEAM/Elixir metrics
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: LocationSharingWeb.Router},
      {Plugins.Ecto, repos: [LocationSharing.Repo]}
      
      # Custom application metrics will be added once core setup works
      # LocationSharing.PromEx.SessionServerMetrics,
      # LocationSharing.PromEx.LocationMetrics,
      # LocationSharing.PromEx.WebSocketMetrics
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "location_sharing_prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      # Built-in dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      
      # Custom dashboards
      {:location_sharing, "session_server.json"},
      {:location_sharing, "websocket_performance.json"},
      {:location_sharing, "backend_comparison.json"}
    ]
  end
end