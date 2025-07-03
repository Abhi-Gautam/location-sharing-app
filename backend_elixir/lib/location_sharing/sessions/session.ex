defmodule LocationSharing.Sessions.Session do
  @moduledoc """
  Session schema for real-time location sharing sessions.

  A session represents a group location sharing instance with the following features:
  - Anonymous participants join via link
  - Maximum 24-hour duration with 1-hour inactivity timeout
  - Creator can manually end the session
  - Supports up to 50 participants per session
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias LocationSharing.Sessions.Participant

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t() | nil,
          creator_id: Ecto.UUID.t() | nil,
          is_active: boolean(),
          last_activity: DateTime.t(),
          expires_at: DateTime.t() | nil,
          created_at: DateTime.t(),
          participants: [Participant.t()] | Ecto.Association.NotLoaded.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :name, :string
    field :creator_id, :binary_id
    field :is_active, :boolean, default: true
    field :last_activity, :utc_datetime
    field :expires_at, :utc_datetime

    has_many :participants, Participant, foreign_key: :session_id

    timestamps(type: :utc_datetime, inserted_at: :created_at, updated_at: false)
  end

  @doc """
  Creates a changeset for creating a new session.

  ## Parameters
    * `attrs` - A map containing session attributes

  ## Examples
      iex> create_changeset(%{name: "Weekend Trip"})
      %Ecto.Changeset{}
  """
  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:name, :creator_id, :expires_at])
    |> validate_length(:name, max: 255)
    |> put_default_values()
    |> validate_required([:is_active, :last_activity])
  end

  @doc """
  Creates a changeset for updating session activity.

  ## Parameters
    * `session` - The session struct
    * `attrs` - A map containing attributes to update

  ## Examples
      iex> update_activity_changeset(%Session{}, %{last_activity: DateTime.utc_now()})
      %Ecto.Changeset{}
  """
  @spec update_activity_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_activity_changeset(%__MODULE__{} = session, attrs \\ %{}) do
    session
    |> cast(attrs, [:last_activity, :is_active])
    |> validate_required([:last_activity])
  end

  @doc """
  Creates a changeset for ending a session.

  ## Parameters
    * `session` - The session struct

  ## Examples
      iex> end_session_changeset(%Session{})
      %Ecto.Changeset{}
  """
  @spec end_session_changeset(t()) :: Ecto.Changeset.t()
  def end_session_changeset(%__MODULE__{} = session) do
    session
    |> change(%{is_active: false})
  end

  @doc """
  Query for active sessions.

  ## Examples
      iex> active_sessions()
      #Ecto.Query<...>
  """
  @spec active_sessions() :: Ecto.Query.t()
  def active_sessions do
    from s in __MODULE__,
      where: s.is_active == true and (is_nil(s.expires_at) or s.expires_at > ^DateTime.utc_now())
  end

  @doc """
  Query for expired sessions.

  ## Examples
      iex> expired_sessions()
      #Ecto.Query<...>
  """
  @spec expired_sessions() :: Ecto.Query.t()
  def expired_sessions do
    now = DateTime.utc_now()
    
    from s in __MODULE__,
      where: s.is_active == true and (
        (not is_nil(s.expires_at) and s.expires_at <= ^now) or
        s.last_activity <= ^DateTime.add(now, -3600, :second)
      )
  end

  @doc """
  Query for sessions by ID with preloaded participants.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> by_id_with_participants("uuid")
      #Ecto.Query<...>
  """
  @spec by_id_with_participants(Ecto.UUID.t()) :: Ecto.Query.t()
  def by_id_with_participants(session_id) do
    from s in __MODULE__,
      where: s.id == ^session_id,
      preload: [:participants]
  end

  # Private helper functions

  defp put_default_values(changeset) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    changeset
    |> put_change(:last_activity, now)
    |> put_change(:is_active, true)
    |> maybe_put_default_expires_at()
  end

  defp maybe_put_default_expires_at(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        # Default to 24 hours from now
        expires_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(24 * 3600, :second)
        put_change(changeset, :expires_at, expires_at)
      
      _ ->
        changeset
    end
  end
end