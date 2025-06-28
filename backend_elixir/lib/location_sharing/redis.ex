defmodule LocationSharing.Redis do
  @moduledoc """
  Redis client and operations for location sharing application.

  Handles real-time location data with the following Redis data structures:
  - `locations:{session_id}:{user_id}` - Location data with 30s TTL
  - `session_participants:{session_id}` - Set of active participant user IDs
  - `connections:{user_id}` - WebSocket connection mapping
  - `session_activity:{session_id}` - Session activity timestamps

  All location data is stored temporarily in Redis with automatic expiration.
  """

  @behaviour Access

  require Logger

  @location_ttl 30
  @activity_ttl 3600

  # Location data operations

  @doc """
  Stores location data for a user in a session with TTL.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string
    * `location_data` - Map containing lat, lng, accuracy, timestamp

  ## Examples
      iex> set_location("session123", "user456", %{lat: 37.7749, lng: -122.4194, accuracy: 5.0, timestamp: "2025-01-15T10:30:00Z"})
      :ok
  """
  @spec set_location(String.t(), String.t(), map()) :: :ok | {:error, term()}
  def set_location(session_id, user_id, location_data) do
    key = location_key(session_id, user_id)
    json_data = Jason.encode!(location_data)
    
    case Redix.command(:redix, ["SETEX", key, @location_ttl, json_data]) do
      {:ok, "OK"} -> 
        Logger.debug("Location stored for user #{user_id} in session #{session_id}")
        :ok
      
      {:error, reason} ->
        Logger.error("Failed to store location: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves location data for a user in a session.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string

  ## Examples
      iex> get_location("session123", "user456")
      {:ok, %{lat: 37.7749, lng: -122.4194, accuracy: 5.0, timestamp: "2025-01-15T10:30:00Z"}}
  """
  @spec get_location(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found} | {:error, term()}
  def get_location(session_id, user_id) do
    key = location_key(session_id, user_id)
    
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} ->
        {:error, :not_found}
      
      {:ok, json_data} ->
        case Jason.decode(json_data) do
          {:ok, location_data} -> {:ok, location_data}
          {:error, reason} -> {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves all current locations for participants in a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> get_session_locations("session123")
      {:ok, [%{user_id: "user456", lat: 37.7749, lng: -122.4194, accuracy: 5.0, timestamp: "2025-01-15T10:30:00Z"}]}
  """
  @spec get_session_locations(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_session_locations(session_id) do
    with {:ok, user_ids} <- get_session_participants(session_id) do
      locations = 
        user_ids
        |> Enum.map(fn user_id ->
          case get_location(session_id, user_id) do
            {:ok, location_data} -> Map.put(location_data, :user_id, user_id)
            {:error, _} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      
      {:ok, locations}
    end
  end

  @doc """
  Removes location data for a user.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string

  ## Examples
      iex> delete_location("session123", "user456")
      :ok
  """
  @spec delete_location(String.t(), String.t()) :: :ok | {:error, term()}
  def delete_location(session_id, user_id) do
    key = location_key(session_id, user_id)
    
    case Redix.command(:redix, ["DEL", key]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Session participant operations

  @doc """
  Adds a participant to a session's active participants set.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string

  ## Examples
      iex> add_session_participant("session123", "user456")
      :ok
  """
  @spec add_session_participant(String.t(), String.t()) :: :ok | {:error, term()}
  def add_session_participant(session_id, user_id) do
    key = participants_key(session_id)
    
    case Redix.command(:redix, ["SADD", key, user_id]) do
      {:ok, _} -> 
        update_session_activity(session_id)
        :ok
      
      {:error, reason} -> 
        {:error, reason}
    end
  end

  @doc """
  Removes a participant from a session's active participants set.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string

  ## Examples
      iex> remove_session_participant("session123", "user456")
      :ok
  """
  @spec remove_session_participant(String.t(), String.t()) :: :ok | {:error, term()}
  def remove_session_participant(session_id, user_id) do
    key = participants_key(session_id)
    
    with {:ok, _} <- Redix.command(:redix, ["SREM", key, user_id]),
         :ok <- delete_location(session_id, user_id),
         :ok <- delete_connection(user_id) do
      update_session_activity(session_id)
      :ok
    end
  end

  @doc """
  Gets all active participants for a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> get_session_participants("session123")
      {:ok, ["user456", "user789"]}
  """
  @spec get_session_participants(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def get_session_participants(session_id) do
    key = participants_key(session_id)
    
    case Redix.command(:redix, ["SMEMBERS", key]) do
      {:ok, members} -> {:ok, members}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the count of active participants in a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> get_session_participant_count("session123")
      {:ok, 2}
  """
  @spec get_session_participant_count(String.t()) :: {:ok, integer()} | {:error, term()}
  def get_session_participant_count(session_id) do
    key = participants_key(session_id)
    
    case Redix.command(:redix, ["SCARD", key]) do
      {:ok, count} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if a user is an active participant in a session.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string

  ## Examples
      iex> is_session_participant?("session123", "user456")
      {:ok, true}
  """
  @spec is_session_participant?(String.t(), String.t()) :: {:ok, boolean()} | {:error, term()}
  def is_session_participant?(session_id, user_id) do
    key = participants_key(session_id)
    
    case Redix.command(:redix, ["SISMEMBER", key, user_id]) do
      {:ok, 1} -> {:ok, true}
      {:ok, 0} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  # WebSocket connection operations

  @doc """
  Maps a user ID to a WebSocket connection ID.

  ## Parameters
    * `user_id` - The user ID string
    * `connection_id` - The WebSocket connection identifier

  ## Examples
      iex> set_connection("user456", "conn_abc123")
      :ok
  """
  @spec set_connection(String.t(), String.t()) :: :ok | {:error, term()}
  def set_connection(user_id, connection_id) do
    key = connection_key(user_id)
    
    case Redix.command(:redix, ["SET", key, connection_id]) do
      {:ok, "OK"} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the WebSocket connection ID for a user.

  ## Parameters
    * `user_id` - The user ID string

  ## Examples
      iex> get_connection("user456")
      {:ok, "conn_abc123"}
  """
  @spec get_connection(String.t()) :: {:ok, String.t()} | {:error, :not_found} | {:error, term()}
  def get_connection(user_id) do
    key = connection_key(user_id)
    
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, connection_id} -> {:ok, connection_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes a WebSocket connection mapping.

  ## Parameters
    * `user_id` - The user ID string

  ## Examples
      iex> delete_connection("user456")
      :ok
  """
  @spec delete_connection(String.t()) :: :ok | {:error, term()}
  def delete_connection(user_id) do
    key = connection_key(user_id)
    
    case Redix.command(:redix, ["DEL", key]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Session activity operations

  @doc """
  Updates the last activity timestamp for a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> update_session_activity("session123")
      :ok
  """
  @spec update_session_activity(String.t()) :: :ok | {:error, term()}
  def update_session_activity(session_id) do
    key = activity_key(session_id)
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    
    case Redix.command(:redix, ["SETEX", key, @activity_ttl, timestamp]) do
      {:ok, "OK"} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the last activity timestamp for a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> get_session_activity("session123")
      {:ok, ~U[2025-01-15 10:30:00Z]}
  """
  @spec get_session_activity(String.t()) :: {:ok, DateTime.t()} | {:error, :not_found} | {:error, term()}
  def get_session_activity(session_id) do
    key = activity_key(session_id)
    
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} ->
        {:error, :not_found}
      
      {:ok, timestamp_str} ->
        case Integer.parse(timestamp_str) do
          {timestamp, ""} -> {:ok, DateTime.from_unix!(timestamp)}
          _ -> {:error, :invalid_timestamp}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Cleanup operations

  @doc """
  Cleans up all Redis data for a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> cleanup_session("session123")
      :ok
  """
  @spec cleanup_session(String.t()) :: :ok | {:error, term()}
  def cleanup_session(session_id) do
    with {:ok, user_ids} <- get_session_participants(session_id) do
      # Delete all location data for participants
      Enum.each(user_ids, fn user_id ->
        delete_location(session_id, user_id)
        delete_connection(user_id)
      end)
      
      # Delete participants set and activity
      participants_key = participants_key(session_id)
      activity_key = activity_key(session_id)
      
      case Redix.command(:redix, ["DEL", participants_key, activity_key]) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Access behaviour implementation for process registry

  @impl Access
  def fetch(term, key) do
    case get(term, key) do
      nil -> :error
      value -> {:ok, value}
    end
  end

  @impl Access
  def get_and_update(data, key, function) do
    current_value = get(data, key)
    case function.(current_value) do
      {get_value, update_value} ->
        new_data = put(data, key, update_value)
        {get_value, new_data}
      :pop ->
        new_data = delete(data, key)
        {current_value, new_data}
    end
  end

  @impl Access
  def pop(data, key, default \\ nil) do
    case get(data, key) do
      nil -> {default, data}
      value -> {value, delete(data, key)}
    end
  end

  # Private helper functions

  defp location_key(session_id, user_id), do: "locations:#{session_id}:#{user_id}"
  defp participants_key(session_id), do: "session_participants:#{session_id}"
  defp connection_key(user_id), do: "connections:#{user_id}"
  defp activity_key(session_id), do: "session_activity:#{session_id}"

  # Helper functions for process operations
  
  defp get(term, key) do
    case :ets.lookup(term, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  defp put(term, key, value) do
    :ets.insert(term, {key, value})
    term
  end

  defp delete(term, key) do
    :ets.delete(term, key)
    term
  end
end