defmodule LocationSharing.PromEx.WebSocketMetrics do
  @moduledoc """
  Custom PromEx plugin for WebSocket and Phoenix Channel metrics.
  
  Tracks WebSocket connection patterns, message throughput, and
  channel performance specific to location sharing.
  """

  use PromEx.Plugin
  
  alias PromEx.MetricTypes.{Event, Polling}
  alias Telemetry.Metrics

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :location_sharing_websocket_events,
      [
        # WebSocket connection events
        Metrics.counter(
          "location_sharing.websocket.connections_opened_total",
          event_name: [:location_sharing, :websocket, :connection, :opened],
          description: "Total number of WebSocket connections opened",
          tag_values: &{&1.session_id, &1.user_id}
        ),

        Metrics.counter(
          "location_sharing.websocket.connections_closed_total",
          event_name: [:location_sharing, :websocket, :connection, :closed],
          description: "Total number of WebSocket connections closed",
          tag_values: &{&1.session_id, &1.user_id, &1.reason}
        ),

        # Phoenix Channel events
        Metrics.counter(
          "location_sharing.channel.joins_total",
          event_name: [:location_sharing, :channel, :join],
          description: "Total number of channel joins",
          tag_values: &{&1.session_id, &1.user_id, &1.channel_name}
        ),

        Metrics.counter(
          "location_sharing.channel.leaves_total",
          event_name: [:location_sharing, :channel, :leave],
          description: "Total number of channel leaves", 
          tag_values: &{&1.session_id, &1.user_id, &1.channel_name, &1.reason}
        ),

        Metrics.distribution(
          "location_sharing.channel.join_duration_seconds",
          event_name: [:location_sharing, :channel, :join],
          description: "Time taken to join a channel",
          measurement: :duration,
          unit: {:native, :second},
          tag_values: &{&1.session_id, &1.channel_name}
        ),

        # Message processing metrics
        Metrics.counter(
          "location_sharing.channel.messages_received_total",
          event_name: [:location_sharing, :channel, :message, :received],
          description: "Total number of messages received on channels",
          tag_values: &{&1.session_id, &1.message_type, &1.channel_name}
        ),

        Metrics.counter(
          "location_sharing.channel.messages_sent_total",
          event_name: [:location_sharing, :channel, :message, :sent],
          description: "Total number of messages sent to channels",
          tag_values: &{&1.session_id, &1.message_type, &1.channel_name}
        ),

        Metrics.distribution(
          "location_sharing.channel.message_processing_duration_seconds",
          event_name: [:location_sharing, :channel, :message, :processed],
          description: "Time taken to process channel messages",
          measurement: :duration,
          unit: {:native, :second},
          tag_values: &{&1.session_id, &1.message_type}
        ),

        # Real-time performance metrics
        Metrics.distribution(
          "location_sharing.channel.broadcast_latency_seconds",
          event_name: [:location_sharing, :channel, :broadcast, :sent],
          description: "Latency for broadcasting messages to all channel subscribers",
          measurement: :latency,
          unit: {:native, :second},
          tag_values: &{&1.session_id, &1.message_type, &1.subscriber_count}
        ),

        # Error tracking
        Metrics.counter(
          "location_sharing.websocket.errors_total",
          event_name: [:location_sharing, :websocket, :error],
          description: "Total number of WebSocket errors",
          tag_values: &{&1.session_id, &1.user_id, &1.error_type}
        ),

        Metrics.counter(
          "location_sharing.channel.errors_total",
          event_name: [:location_sharing, :channel, :error],
          description: "Total number of channel errors",
          tag_values: &{&1.session_id, &1.channel_name, &1.error_type}
        )
      ]
    )
  end

  @impl true
  def polling_metrics(_opts) do
    Polling.build(
      :location_sharing_websocket_polling,
      [
        # Current connection state
        Metrics.last_value(
          "location_sharing.websocket.active_connections_total",
          {__MODULE__, :get_active_connections_count, []},
          description: "Number of currently active WebSocket connections"
        ),

        Metrics.last_value(
          "location_sharing.channel.active_channels_total",
          {__MODULE__, :get_active_channels_count, []},
          description: "Number of currently active channels"
        ),

        # Channel subscription metrics
        Metrics.last_value(
          "location_sharing.channel.total_subscriptions",
          {__MODULE__, :get_total_subscriptions, []},
          description: "Total number of channel subscriptions"
        ),

        Metrics.last_value(
          "location_sharing.channel.average_subscribers_per_channel",
          {__MODULE__, :get_average_subscribers_per_channel, []},
          description: "Average number of subscribers per channel"
        ),

        # Memory usage for WebSocket/Channel system
        Metrics.last_value(
          "location_sharing.websocket.memory_usage_bytes",
          {__MODULE__, :get_websocket_memory_usage, []},
          description: "Memory used by WebSocket/Channel processes"
        ),

        # Message queue metrics
        Metrics.last_value(
          "location_sharing.channel.message_queue_length_total",
          {__MODULE__, :get_total_message_queue_length, []},
          description: "Total length of all channel message queues"
        )
      ]
    )
  end

  # Callback functions for polling metrics

  def get_active_connections_count do
    # Count active Phoenix Channel processes
    LocationSharingWeb.Endpoint
    |> Phoenix.PubSub.subscribers(LocationSharing.PubSub, "session:*")
    |> length()
  rescue
    _ -> 0
  end

  def get_active_channels_count do
    # Count unique channel topics that have subscribers
    all_topics()
    |> length()
  end

  def get_total_subscriptions do
    all_topics()
    |> Enum.map(fn topic ->
      LocationSharingWeb.Endpoint
      |> Phoenix.PubSub.subscribers(LocationSharing.PubSub, topic)
      |> length()
    end)
    |> Enum.sum()
  end

  def get_average_subscribers_per_channel do
    topics = all_topics()
    
    if length(topics) == 0 do
      0.0
    else
      total_subs = get_total_subscriptions()
      total_subs / length(topics)
    end
  end

  def get_websocket_memory_usage do
    # Estimate memory usage by counting processes related to channels
    Process.list()
    |> Enum.filter(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          Enum.any?(dict, fn
            {:"$initial_call", {Phoenix.Channel, _, _}} -> true
            {:"$initial_call", {LocationSharingWeb.LocationChannel, _, _}} -> true
            _ -> false
          end)
        nil -> false
      end
    end)
    |> Enum.map(fn pid ->
      case Process.info(pid, :memory) do
        {:memory, memory} -> memory
        nil -> 0
      end
    end)
    |> Enum.sum()
  rescue
    _ -> 0
  end

  def get_total_message_queue_length do
    # Get message queue lengths for channel processes
    Process.list()
    |> Enum.filter(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          Enum.any?(dict, fn
            {:"$initial_call", {Phoenix.Channel, _, _}} -> true
            {:"$initial_call", {LocationSharingWeb.LocationChannel, _, _}} -> true
            _ -> false
          end)
        nil -> false
      end
    end)
    |> Enum.map(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len
        nil -> 0
      end
    end)
    |> Enum.sum()
  rescue
    _ -> 0
  end

  # Helper functions

  defp all_topics do
    # Get all session topics that currently have subscribers
    # This is a simplified approach - in production you might want to track this more efficiently
    ["session:test"]  # Placeholder - would need to track active session topics
  end
end