defmodule LocationSharing.Guardian do
  @moduledoc """
  Guardian implementation for JWT authentication in the location sharing application.

  This module handles JWT token generation and verification for WebSocket authentication.
  Tokens contain participant information for session access validation.
  """

  use Guardian, otp_app: :location_sharing

  require Logger
  alias LocationSharing.Sessions.Participant

  @doc """
  Encodes the participant information into the JWT subject.

  ## Parameters
    * `participant` - The participant struct or map

  ## Examples
      iex> subject_for_token(%{id: "uuid", session_id: "session_uuid", user_id: "user123"}, _claims)
      {:ok, "uuid"}
  """
  @impl true
  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(%{"id" => id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :invalid_resource}

  @doc """
  Retrieves the participant from the JWT subject.

  ## Parameters
    * `subject` - The JWT subject (participant ID)
    * `claims` - The JWT claims

  ## Examples
      iex> resource_from_claims(%{"sub" => "uuid", "session_id" => "session_uuid"})
      {:ok, %{participant_id: "uuid", session_id: "session_uuid"}}
  """
  @impl true
  def resource_from_claims(%{"sub" => participant_id, "session_id" => session_id, "user_id" => user_id}) do
    resource = %{
      participant_id: participant_id,
      session_id: session_id,
      user_id: user_id
    }
    {:ok, resource}
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}

  @doc """
  Generates a JWT token for a participant.

  ## Parameters
    * `participant` - The participant struct

  ## Examples
      iex> generate_token(%Participant{id: "uuid", session_id: "session_uuid", user_id: "user123"})
      {:ok, "jwt_token", %{}}
  """
  @spec generate_token(Participant.t()) :: {:ok, String.t(), map()} | {:error, term()}
  def generate_token(%Participant{} = participant) do
    claims = %{
      "session_id" => participant.session_id,
      "user_id" => participant.user_id,
      "display_name" => participant.display_name
    }
    
    encode_and_sign(participant, claims)
  end

  @doc """
  Verifies a JWT token and extracts participant information.

  ## Parameters
    * `token` - The JWT token string

  ## Examples
      iex> verify_token("jwt_token")
      {:ok, %{participant_id: "uuid", session_id: "session_uuid", user_id: "user123"}}
  """
  @spec verify_token(String.t()) :: {:ok, map()} | {:error, term()}
  def verify_token(token) do
    case decode_and_verify(token) do
      {:ok, claims} -> resource_from_claims(claims)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates that a participant is authorized for a specific session.

  ## Parameters
    * `token` - The JWT token string
    * `session_id` - The session UUID to validate against

  ## Examples
      iex> validate_session_access("jwt_token", "session_uuid")
      {:ok, %{participant_id: "uuid", user_id: "user123"}}
  """
  @spec validate_session_access(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def validate_session_access(token, session_id) do
    case verify_token(token) do
      {:ok, %{session_id: ^session_id} = resource} ->
        {:ok, resource}
      
      {:ok, %{session_id: different_session_id}} ->
        {:error, {:unauthorized, "Token is for session #{different_session_id}, not #{session_id}"}}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a WebSocket authentication token for a participant.

  This is a convenience function that generates a token with WebSocket-specific claims.

  ## Parameters
    * `participant` - The participant struct

  ## Examples
      iex> create_websocket_token(%Participant{})
      {:ok, "jwt_token"}
  """
  @spec create_websocket_token(Participant.t()) :: {:ok, String.t()} | {:error, term()}
  def create_websocket_token(%Participant{} = participant) do
    case generate_token(participant) do
      {:ok, token, _claims} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates a WebSocket connection token.

  ## Parameters
    * `token` - The JWT token from WebSocket connection

  ## Examples
      iex> validate_websocket_token("jwt_token")
      {:ok, %{participant_id: "uuid", session_id: "session_uuid", user_id: "user123"}}
  """
  @spec validate_websocket_token(String.t()) :: {:ok, map()} | {:error, term()}
  def validate_websocket_token(token) do
    verify_token(token)
  end

  # Guardian callbacks

  @impl Guardian
  def after_encode_and_sign(resource, _claims, token, _options) do
    # Log successful token generation for monitoring
    case resource do
      %{user_id: user_id, session_id: session_id} ->
        Logger.debug("Generated JWT token for user #{user_id} in session #{session_id}")
      
      _ ->
        Logger.debug("Generated JWT token")
    end
    
    {:ok, token}
  end

  @impl Guardian
  def on_verify(claims, _token, _options) do
    # Log successful token verification
    case claims do
      %{"user_id" => user_id, "session_id" => session_id} ->
        Logger.debug("Verified JWT token for user #{user_id} in session #{session_id}")
      
      _ ->
        Logger.debug("Verified JWT token")
    end
    
    {:ok, claims}
  end

  @impl Guardian
  def on_revoke(claims, _token, _options) do
    # Handle token revocation if needed
    Logger.debug("Revoked JWT token")
    {:ok, claims}
  end
end