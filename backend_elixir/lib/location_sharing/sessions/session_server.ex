defmodule LocationSharing.Sessions.SessionServer do
  @moduledoc """
  GenServer that manages session state using pure BEAM processes instead of Redis.
  
  This implementation demonstrates the "Internal Coordination" approach where all
  state management and coordination happens within the BEAM VM using:
  - GenServer state for session data
  - ETS tables for fast location lookups
  - Phoenix.PubSub for message broadcasting
  - Process monitoring for fault tolerance
  
  Each active session gets its own SessionServer process that manages:
  - Participant list and metadata
  - Location data with automatic TTL cleanup
  - Session lifecycle and expiration
  - Real-time message broadcasting
  """

  use GenServer, restart: :temporary
  
  require Logger
  
  alias LocationSharing.{Repo, Sessions.Session}
  alias Phoenix.PubSub

  # Session state
  defstruct [
    :session_id,
    :session_data,
    :participants,
    :locations_table,
    :created_at,
    :expires_at,
    :cleanup_timer,
    :metrics
  ]

  # Configuration
  @location_ttl_ms 30_000  # 30 seconds
  @cleanup_interval_ms 5_000  # 5 seconds
  @max_participants 50

  ## Client API

  @doc """
  Starts a SessionServer for the given session ID.
  """
  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  @doc """
  Gets or starts a SessionServer for the given session ID.
  """
  def get_or_start(session_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] when is_pid(pid) ->
        {:ok, pid}
      
      [] ->
        case DynamicSupervisor.start_child(
          LocationSharing.Sessions.DynamicSupervisor,
          {__MODULE__, session_id}
        ) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end
    end
  end

  @doc """
  Adds a participant to the session.
  """
  def add_participant(session_id, user_id, participant_data) do
    with {:ok, pid} <- get_or_start(session_id) do
      GenServer.call(pid, {:add_participant, user_id, participant_data})
    end
  end

  @doc """
  Removes a participant from the session.
  """
  def remove_participant(session_id, user_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.call(pid, {:remove_participant, user_id})
      [] -> {:error, :session_not_found}
    end
  end

  @doc """
  Updates location for a participant.
  """
  def update_location(session_id, user_id, location_data) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.call(pid, {:update_location, user_id, location_data})
      [] -> {:error, :session_not_found}
    end
  end

  @doc """
  Gets all current participants in the session.
  """
  def get_participants(session_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.call(pid, :get_participants)
      [] -> {:error, :session_not_found}
    end
  end

  @doc """
  Gets all current locations in the session.
  """
  def get_locations(session_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.call(pid, :get_locations)
      [] -> {:error, :session_not_found}
    end
  end

  @doc """
  Gets session statistics for monitoring.
  """
  def get_stats(session_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.call(pid, :get_stats)
      [] -> {:error, :session_not_found}
    end
  end

  @doc """
  Updates participant activity timestamp.
  """
  def update_activity(session_id, user_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.cast(pid, {:update_activity, user_id})
      [] -> :ok
    end
  end

  @doc """
  Terminates the session server.
  """
  def terminate_session(session_id) do
    case Registry.lookup(LocationSharing.Sessions.Registry, session_id) do
      [{pid, _}] -> GenServer.call(pid, :terminate_session)
      [] -> :ok
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(session_id) do
    Logger.info("Starting SessionServer for session #{session_id}")
    
    # Load session data from database
    case Repo.get(Session, session_id) do
      nil ->
        Logger.error("Session #{session_id} not found in database")
        {:stop, :session_not_found}
      
      %Session{is_active: false} ->
        Logger.error("Session #{session_id} is not active")
        {:stop, :session_inactive}
      
      session_data ->
        # Create ETS table for fast location lookups
        table_name = :"locations_#{session_id}"
        locations_table = :ets.new(table_name, [
          :set, 
          :public, 
          :named_table,
          {:read_concurrency, true}
        ])
        
        # Set up cleanup timer
        cleanup_timer = Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
        
        # Initialize state
        state = %__MODULE__{
          session_id: session_id,
          session_data: session_data,
          participants: %{},
          locations_table: locations_table,
          created_at: DateTime.utc_now(),
          expires_at: session_data.expires_at,
          cleanup_timer: cleanup_timer,
          metrics: %{
            participants_joined: 0,
            participants_left: 0,
            location_updates: 0,
            messages_broadcast: 0
          }
        }
        
        # Emit telemetry for PromEx
        :telemetry.execute(
          [:location_sharing, :session_server, :session, :created],
          %{count: 1},
          %{session_id: session_id}
        )
        
        Logger.info("SessionServer started for session #{session_id}")
        {:ok, state}
    end
  end

  @impl true
  def handle_call({:add_participant, user_id, participant_data}, _from, state) do
    if map_size(state.participants) >= @max_participants do
      {:reply, {:error, :session_full}, state}
    else
      # Add participant to state
      participant_info = Map.merge(participant_data, %{
        joined_at: DateTime.utc_now(),
        last_seen: DateTime.utc_now()
      })
      
      new_participants = Map.put(state.participants, user_id, participant_info)
      
      # Update metrics
      new_metrics = Map.update!(state.metrics, :participants_joined, &(&1 + 1))
      
      # Broadcast participant joined event
      broadcast_message = %{
        type: "participant_joined",
        data: %{
          user_id: user_id,
          display_name: participant_data.display_name,
          avatar_color: participant_data.avatar_color
        }
      }
      
      broadcast_to_session(state.session_id, "participant_joined", broadcast_message)
      
      new_state = %{state | 
        participants: new_participants,
        metrics: Map.update!(new_metrics, :messages_broadcast, &(&1 + 1))
      }
      
      # Emit telemetry for PromEx
      :telemetry.execute(
        [:location_sharing, :session_server, :participant, :joined],
        %{count: 1, total_participants: map_size(new_participants)},
        %{session_id: state.session_id, user_id: user_id}
      )
      
      Logger.debug("Participant #{user_id} joined session #{state.session_id}")
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:remove_participant, user_id}, _from, state) do
    case Map.get(state.participants, user_id) do
      nil ->
        {:reply, {:error, :participant_not_found}, state}
      
      _participant_info ->
        # Remove participant from state
        new_participants = Map.delete(state.participants, user_id)
        
        # Remove location data
        :ets.delete(state.locations_table, user_id)
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :participants_left, &(&1 + 1))
        
        # Broadcast participant left event
        broadcast_message = %{
          type: "participant_left",
          data: %{user_id: user_id}
        }
        
        broadcast_to_session(state.session_id, "participant_left", broadcast_message)
        
        new_state = %{state | 
          participants: new_participants,
          metrics: Map.update!(new_metrics, :messages_broadcast, &(&1 + 1))
        }
        
        # Emit telemetry for PromEx
        :telemetry.execute(
          [:location_sharing, :session_server, :participant, :left],
          %{count: 1, total_participants: map_size(new_participants)},
          %{session_id: state.session_id, user_id: user_id, reason: "manual"}
        )
        
        Logger.debug("Participant #{user_id} left session #{state.session_id}")
        
        # Check if session should be terminated (no participants)
        if map_size(new_participants) == 0 do
          Logger.info("No participants left in session #{state.session_id}, scheduling termination")
          Process.send_after(self(), :check_empty_session, 30_000)
        end
        
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:update_location, user_id, location_data}, _from, state) do
    case Map.get(state.participants, user_id) do
      nil ->
        {:reply, {:error, :participant_not_found}, state}
      
      _participant_info ->
        # Store location with timestamp for TTL
        location_with_meta = Map.merge(location_data, %{
          stored_at: System.monotonic_time(:millisecond),
          expires_at: System.monotonic_time(:millisecond) + @location_ttl_ms
        })
        
        :ets.insert(state.locations_table, {user_id, location_with_meta})
        
        # Update participant last seen
        updated_participants = Map.update!(state.participants, user_id, fn participant ->
          Map.put(participant, :last_seen, DateTime.utc_now())
        end)
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :location_updates, &(&1 + 1))
        
        # Broadcast location update
        broadcast_message = %{
          type: "location_update",
          data: Map.merge(location_data, %{user_id: user_id})
        }
        
        broadcast_to_session(state.session_id, "location_update", broadcast_message)
        
        new_state = %{state | 
          participants: updated_participants,
          metrics: Map.update!(new_metrics, :messages_broadcast, &(&1 + 1))
        }
        
        # Emit telemetry for PromEx
        :telemetry.execute(
          [:location_sharing, :session_server, :location, :updated],
          %{duration: 1_000_000}, # 1ms in nanoseconds as placeholder
          %{session_id: state.session_id, user_id: user_id}
        )
        
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_participants, _from, state) do
    participants = Enum.map(state.participants, fn {user_id, participant_info} ->
      Map.put(participant_info, :user_id, user_id)
    end)
    
    {:reply, {:ok, participants}, state}
  end

  @impl true
  def handle_call(:get_locations, _from, state) do
    current_time = System.monotonic_time(:millisecond)
    
    locations = 
      :ets.tab2list(state.locations_table)
      |> Enum.filter(fn {_user_id, location_data} ->
        location_data.expires_at > current_time
      end)
      |> Enum.map(fn {user_id, location_data} ->
        Map.merge(location_data, %{user_id: user_id})
        |> Map.drop([:stored_at, :expires_at])
      end)
    
    {:reply, {:ok, locations}, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    current_time = System.monotonic_time(:millisecond)
    
    active_locations = 
      :ets.tab2list(state.locations_table)
      |> Enum.count(fn {_user_id, location_data} ->
        location_data.expires_at > current_time
      end)
    
    stats = %{
      session_id: state.session_id,
      participant_count: map_size(state.participants),
      active_locations: active_locations,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.created_at),
      metrics: state.metrics
    }
    
    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_call(:terminate_session, _from, state) do
    Logger.info("Terminating session #{state.session_id}")
    
    # Broadcast session ended to all participants
    broadcast_message = %{
      type: "session_ended",
      data: %{reason: "terminated"}
    }
    
    broadcast_to_session(state.session_id, "session_ended", broadcast_message)
    
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_cast({:update_activity, user_id}, state) do
    case Map.get(state.participants, user_id) do
      nil ->
        {:noreply, state}
      
      _participant_info ->
        updated_participants = Map.update!(state.participants, user_id, fn participant ->
          Map.put(participant, :last_seen, DateTime.utc_now())
        end)
        
        {:noreply, %{state | participants: updated_participants}}
    end
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    # Clean up expired locations
    current_time = System.monotonic_time(:millisecond)
    
    expired_keys = 
      :ets.tab2list(state.locations_table)
      |> Enum.filter(fn {_user_id, location_data} ->
        location_data.expires_at <= current_time
      end)
      |> Enum.map(fn {user_id, _location_data} -> user_id end)
    
    Enum.each(expired_keys, fn user_id ->
      :ets.delete(state.locations_table, user_id)
    end)
    
    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired locations in session #{state.session_id}")
    end
    
    # Check session expiration
    if state.expires_at && DateTime.compare(DateTime.utc_now(), state.expires_at) == :gt do
      Logger.info("Session #{state.session_id} has expired")
      
      broadcast_message = %{
        type: "session_ended",
        data: %{reason: "expired"}
      }
      
      broadcast_to_session(state.session_id, "session_ended", broadcast_message)
      {:stop, :normal, state}
    else
      # Schedule next cleanup
      new_timer = Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
      {:noreply, %{state | cleanup_timer: new_timer}}
    end
  end

  @impl true
  def handle_info(:check_empty_session, state) do
    if map_size(state.participants) == 0 do
      Logger.info("Session #{state.session_id} is empty, terminating")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message in SessionServer: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("SessionServer terminating for session #{state.session_id}: #{inspect(reason)}")
    
    # Cancel cleanup timer
    if state.cleanup_timer do
      Process.cancel_timer(state.cleanup_timer)
    end
    
    # Clean up ETS table
    if :ets.info(state.locations_table) != :undefined do
      :ets.delete(state.locations_table)
    end
    
    # Emit telemetry
    :telemetry.execute(
      [:location_sharing, :session_server, :terminated],
      %{count: 1, uptime: DateTime.diff(DateTime.utc_now(), state.created_at)},
      %{session_id: state.session_id, reason: reason}
    )
    
    :ok
  end

  ## Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {LocationSharing.Sessions.Registry, session_id}}
  end

  defp broadcast_to_session(session_id, event, message) do
    PubSub.broadcast(
      LocationSharing.PubSub,
      "session:#{session_id}",
      {String.to_atom(event), message}
    )
  end
end