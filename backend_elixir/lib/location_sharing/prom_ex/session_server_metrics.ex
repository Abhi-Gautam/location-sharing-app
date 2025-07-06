defmodule LocationSharing.PromEx.SessionServerMetrics do
  @moduledoc """
  Custom PromEx plugin for SessionServer (BEAM coordination) metrics.
  
  This plugin tracks metrics specific to our BEAM-based coordination system
  to compare against Redis-based coordination in the Rust backend.
  """

  use PromEx.Plugin
  
  alias PromEx.MetricTypes.{Event, Polling}
  import PromEx.MetricTypes.Polling, only: [gauge: 3]
  alias Telemetry.Metrics

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :location_sharing_session_server_events,
      [
        # Session management metrics
        Metrics.counter(
          "location_sharing.session_server.sessions_created_total",
          event_name: [:location_sharing, :session_server, :session, :created],
          description: "Total number of sessions created",
          tag_values: &(&1.session_id)
        ),

        Metrics.counter(
          "location_sharing.session_server.sessions_terminated_total",
          event_name: [:location_sharing, :session_server, :session, :terminated],
          description: "Total number of sessions terminated",
          tag_values: &{&1.session_id, &1.reason}
        ),

        # Participant management metrics
        Metrics.counter(
          "location_sharing.session_server.participants_joined_total",
          event_name: [:location_sharing, :session_server, :participant, :joined],
          description: "Total number of participants joined",
          tag_values: &{&1.session_id, &1.user_id}
        ),

        Metrics.counter(
          "location_sharing.session_server.participants_left_total",
          event_name: [:location_sharing, :session_server, :participant, :left],
          description: "Total number of participants left",
          tag_values: &{&1.session_id, &1.user_id, &1.reason}
        ),

        # Location update metrics
        Metrics.counter(
          "location_sharing.session_server.location_updates_total",
          event_name: [:location_sharing, :session_server, :location, :updated],
          description: "Total number of location updates processed",
          tag_values: &{&1.session_id, &1.user_id}
        ),

        Metrics.distribution(
          "location_sharing.session_server.location_update_duration_seconds",
          event_name: [:location_sharing, :session_server, :location, :updated],
          description: "Time taken to process location updates",
          measurement: :duration,
          unit: {:native, :second},
          tag_values: &(&1.session_id)
        ),

        # GenServer process metrics
        Metrics.distribution(
          "location_sharing.session_server.genserver_call_duration_seconds",
          event_name: [:location_sharing, :session_server, :genserver, :call],
          description: "Time taken for GenServer calls",
          measurement: :duration,
          unit: {:native, :second},
          tag_values: &{&1.session_id, &1.function}
        ),

        # Broadcast metrics (BEAM coordination)
        Metrics.counter(
          "location_sharing.session_server.broadcasts_sent_total",
          event_name: [:location_sharing, :session_server, :broadcast, :sent],
          description: "Total number of broadcasts sent via Phoenix.PubSub",
          tag_values: &{&1.session_id, &1.message_type}
        ),

        Metrics.distribution(
          "location_sharing.session_server.broadcast_duration_seconds",
          event_name: [:location_sharing, :session_server, :broadcast, :sent],
          description: "Time taken to broadcast messages",
          measurement: :duration,
          unit: {:native, :second},
          tag_values: &{&1.session_id, &1.message_type}
        )
      ]
    )
  end

  @impl true
  def polling_metrics(_opts) do
    Polling.build(
      :location_sharing_session_server_polling,
      [
        # Active sessions gauge
        Metrics.last_value(
          "location_sharing.session_server.active_sessions_total",
          {__MODULE__, :get_active_sessions_count, []},
          description: "Number of currently active SessionServer processes"
        ),

        # Active participants across all sessions
        Metrics.last_value(
          "location_sharing.session_server.active_participants_total",
          {__MODULE__, :get_active_participants_count, []}, 
          description: "Total number of active participants across all sessions"
        ),

        # ETS table sizes
        Metrics.last_value(
          "location_sharing.session_server.ets_tables_total",
          {__MODULE__, :get_ets_tables_count, []},
          description: "Number of ETS tables (one per session)"
        ),

        Metrics.last_value(
          "location_sharing.session_server.ets_entries_total", 
          {__MODULE__, :get_ets_entries_count, []},
          description: "Total number of location entries in ETS tables"
        ),

        # Memory usage specific to our coordination system
        Metrics.last_value(
          "location_sharing.session_server.memory_usage_bytes",
          {__MODULE__, :get_session_server_memory, []},
          description: "Memory used by SessionServer processes"
        )
      ]
    )
  end

  # Callback functions for polling metrics

  def get_active_sessions_count do
    LocationSharing.Sessions.SessionsSupervisor
    |> DynamicSupervisor.count_children()
    |> Map.get(:active, 0)
  end

  def get_active_participants_count do
    LocationSharing.Sessions.SessionsSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} ->
      if Process.alive?(pid) do
        GenServer.call(pid, :get_participant_count)
      else
        0
      end
    end)
    |> Enum.sum()
  rescue
    _ -> 0
  end

  def get_ets_tables_count do
    :ets.all()
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "session_locations_"))
    |> length()
  end

  def get_ets_entries_count do
    :ets.all()
    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "session_locations_"))
    |> Enum.map(&:ets.info(&1, :size))
    |> Enum.sum()
  rescue
    _ -> 0
  end

  def get_session_server_memory do
    LocationSharing.Sessions.SessionsSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} ->
      if Process.alive?(pid) do
        Process.info(pid, :memory) |> elem(1)
      else
        0
      end
    end)
    |> Enum.sum()
  rescue
    _ -> 0
  end
end