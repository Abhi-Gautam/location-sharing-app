defmodule LocationSharing.PromEx.LocationMetrics do
  @moduledoc """
  Custom PromEx plugin for location-specific metrics.
  
  Tracks location update patterns, geographic distribution, and
  location data processing performance.
  """

  use PromEx.Plugin
  
  alias PromEx.MetricTypes.{Event, Polling}
  alias Telemetry.Metrics

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :location_sharing_location_events,
      [
        # Location processing metrics
        Metrics.counter(
          "location_sharing.location.updates_received_total",
          event_name: [:location_sharing, :location, :update, :received],
          description: "Total number of location updates received",
          tag_values: &{&1.session_id, &1.user_id, &1.update_type}
        ),

        Metrics.counter(
          "location_sharing.location.updates_processed_total",
          event_name: [:location_sharing, :location, :update, :processed],
          description: "Total number of location updates successfully processed",
          tag_values: &{&1.session_id, &1.user_id}
        ),

        Metrics.counter(
          "location_sharing.location.updates_failed_total",
          event_name: [:location_sharing, :location, :update, :failed],
          description: "Total number of location update failures",
          tag_values: &{&1.session_id, &1.user_id, &1.error_type}
        ),

        # Location accuracy and movement metrics
        Metrics.distribution(
          "location_sharing.location.accuracy_meters",
          event_name: [:location_sharing, :location, :update, :processed],
          description: "Location accuracy in meters",
          measurement: :accuracy,
          buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]
        ),

        Metrics.distribution(
          "location_sharing.location.speed_kmh",
          event_name: [:location_sharing, :location, :update, :processed],
          description: "Movement speed in km/h",
          measurement: :speed,
          buckets: [0, 5, 15, 30, 60, 100, 150]
        ),

        # Geographic distribution metrics
        Metrics.counter(
          "location_sharing.location.updates_by_region_total",
          event_name: [:location_sharing, :location, :update, :processed],
          description: "Location updates grouped by geographic region",
          tag_values: &{&1.session_id, &1.country, &1.region}
        ),

        # TTL and cleanup metrics
        Metrics.counter(
          "location_sharing.location.expired_total",
          event_name: [:location_sharing, :location, :expired],
          description: "Total number of expired location entries",
          tag_values: &{&1.session_id, &1.reason}
        ),

        Metrics.distribution(
          "location_sharing.location.ttl_remaining_seconds",
          event_name: [:location_sharing, :location, :cleanup],
          description: "Remaining TTL for location entries during cleanup",
          measurement: :ttl_remaining,
          unit: :second,
          tag_values: &(&1.session_id)
        )
      ]
    )
  end

  @impl true
  def polling_metrics(_opts) do
    Polling.build(
      :location_sharing_location_polling,
      [
        # Current location storage stats
        Metrics.last_value(
          "location_sharing.location.stored_entries_total",
          {__MODULE__, :get_stored_locations_count, []},
          description: "Total number of location entries currently stored"
        ),

        # Movement pattern analysis  
        Metrics.last_value(
          "location_sharing.location.active_users_moving",
          {__MODULE__, :get_moving_users_count, []},
          description: "Number of users currently moving (speed > 1 km/h)"
        ),

        Metrics.last_value(
          "location_sharing.location.active_users_stationary",
          {__MODULE__, :get_stationary_users_count, []},
          description: "Number of users currently stationary (speed <= 1 km/h)"
        ),

        # Geographic spread metrics
        Metrics.last_value(
          "location_sharing.location.geographic_spread_km",
          {__MODULE__, :get_geographic_spread, []},
          description: "Maximum distance between users in active sessions (km)"
        )
      ]
    )
  end

  # Callback functions for polling metrics

  def get_stored_locations_count do
    :ets.all()
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "session_locations_"))
    |> Enum.map(&:ets.info(&1, :size))
    |> Enum.sum()
  rescue
    _ -> 0
  end

  def get_moving_users_count do
    count_users_by_speed(fn speed -> speed > 1.0 end)
  end

  def get_stationary_users_count do
    count_users_by_speed(fn speed -> speed <= 1.0 end)
  end

  def get_geographic_spread do
    # Calculate the maximum distance between any two users across all sessions
    all_locations = get_all_current_locations()
    
    if length(all_locations) < 2 do
      0.0
    else
      all_locations
      |> combinations(2)
      |> Enum.map(&calculate_distance/1)
      |> Enum.max(fn -> 0.0 end)
    end
  end

  # Helper functions

  defp count_users_by_speed(speed_filter) do
    :ets.all()
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "session_locations_"))
    |> Enum.flat_map(fn table ->
      :ets.tab2list(table)
    end)
    |> Enum.count(fn {_user_id, location} ->
      speed = Map.get(location, :speed, 0.0)
      speed_filter.(speed)
    end)
  rescue
    _ -> 0
  end

  defp get_all_current_locations do
    :ets.all()
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "session_locations_"))
    |> Enum.flat_map(fn table ->
      :ets.tab2list(table)
    end)
    |> Enum.map(fn {_user_id, location} -> location end)
  rescue
    _ -> []
  end

  defp combinations(list, n) when n > 0 do
    list
    |> Enum.with_index()
    |> combinations(n, [])
  end

  defp combinations(_, 0, acc), do: [Enum.reverse(acc)]
  defp combinations([], _, _), do: []
  defp combinations([{h, i} | t], n, acc) do
    with_h = combinations(Enum.drop_while(t, fn {_, j} -> j <= i end), n - 1, [h | acc])
    without_h = combinations(t, n, acc)
    with_h ++ without_h
  end

  defp calculate_distance([loc1, loc2]) do
    # Haversine formula for distance calculation
    lat1_rad = loc1.latitude * :math.pi() / 180
    lon1_rad = loc1.longitude * :math.pi() / 180
    lat2_rad = loc2.latitude * :math.pi() / 180
    lon2_rad = loc2.longitude * :math.pi() / 180

    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(dlon / 2) * :math.sin(dlon / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    
    # Earth's radius in kilometers
    6371.0 * c
  end
end