defmodule LocationSharing.Sessions.Participant do
  @moduledoc """
  Participant schema for session participants.

  A participant represents a user in a location sharing session with the following features:
  - Anonymous participation (no account required)
  - Unique display name within session
  - Customizable avatar color
  - Activity tracking for cleanup
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias LocationSharing.Sessions.Session

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          session_id: Ecto.UUID.t(),
          user_id: String.t(),
          display_name: String.t(),
          avatar_color: String.t(),
          last_seen: DateTime.t(),
          is_active: boolean(),
          joined_at: DateTime.t(),
          updated_at: DateTime.t(),
          session: Session.t() | Ecto.Association.NotLoaded.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "participants" do
    field :user_id, :string
    field :display_name, :string
    field :avatar_color, :string, default: "#FF5733"
    field :last_seen, :utc_datetime
    field :is_active, :boolean, default: true

    belongs_to :session, Session, foreign_key: :session_id

    timestamps(type: :utc_datetime, inserted_at: :joined_at)
  end

  @doc """
  Creates a changeset for joining a session.

  ## Parameters
    * `attrs` - A map containing participant attributes

  ## Examples
      iex> join_changeset(%{session_id: "uuid", user_id: "user123", display_name: "John Doe"})
      %Ecto.Changeset{}
  """
  @spec join_changeset(map()) :: Ecto.Changeset.t()
  def join_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:session_id, :user_id, :display_name, :avatar_color])
    |> validate_required([:session_id, :user_id, :display_name])
    |> validate_length(:user_id, max: 255)
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_format(:avatar_color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> put_default_values()
    |> unique_constraint([:session_id, :user_id], name: :participants_session_id_user_id_index)
    |> unique_constraint([:session_id, :display_name], name: :participants_session_id_display_name_index)
  end

  @doc """
  Creates a changeset for updating participant activity.

  ## Parameters
    * `participant` - The participant struct
    * `attrs` - A map containing attributes to update

  ## Examples
      iex> update_activity_changeset(%Participant{}, %{last_seen: DateTime.utc_now()})
      %Ecto.Changeset{}
  """
  @spec update_activity_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_activity_changeset(%__MODULE__{} = participant, attrs \\ %{}) do
    participant
    |> cast(attrs, [:last_seen, :is_active])
    |> validate_required([:last_seen])
  end

  @doc """
  Creates a changeset for leaving a session.

  ## Parameters
    * `participant` - The participant struct

  ## Examples
      iex> leave_changeset(%Participant{})
      %Ecto.Changeset{}
  """
  @spec leave_changeset(t()) :: Ecto.Changeset.t()
  def leave_changeset(%__MODULE__{} = participant) do
    participant
    |> change(%{is_active: false})
  end

  @doc """
  Query for active participants in a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> active_for_session("uuid")
      #Ecto.Query<...>
  """
  @spec active_for_session(Ecto.UUID.t()) :: Ecto.Query.t()
  def active_for_session(session_id) do
    from p in __MODULE__,
      where: p.session_id == ^session_id and p.is_active == true,
      order_by: [asc: p.joined_at]
  end

  @doc """
  Query for a specific participant by session and user ID.

  ## Parameters
    * `session_id` - The session UUID
    * `user_id` - The user ID string

  ## Examples
      iex> by_session_and_user("session_uuid", "user123")
      #Ecto.Query<...>
  """
  @spec by_session_and_user(Ecto.UUID.t(), String.t()) :: Ecto.Query.t()
  def by_session_and_user(session_id, user_id) do
    from p in __MODULE__,
      where: p.session_id == ^session_id and p.user_id == ^user_id
  end

  @doc """
  Query for inactive participants that should be cleaned up.

  ## Parameters
    * `timeout_minutes` - Minutes of inactivity before considering inactive

  ## Examples
      iex> inactive_participants(30)
      #Ecto.Query<...>
  """
  @spec inactive_participants(integer()) :: Ecto.Query.t()
  def inactive_participants(timeout_minutes \\ 30) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -timeout_minutes * 60, :second)
    
    from p in __MODULE__,
      where: p.is_active == true and p.last_seen <= ^cutoff_time
  end

  @doc """
  Query to count active participants in a session.

  ## Parameters
    * `session_id` - The session UUID

  ## Examples
      iex> count_active_for_session("uuid")
      #Ecto.Query<...>
  """
  @spec count_active_for_session(Ecto.UUID.t()) :: Ecto.Query.t()
  def count_active_for_session(session_id) do
    from p in __MODULE__,
      where: p.session_id == ^session_id and p.is_active == true,
      select: count(p.id)
  end

  @doc """
  Generates a random user ID for anonymous participants.

  ## Examples
      iex> generate_user_id()
      "user_abc123def456"
  """
  @spec generate_user_id() :: String.t()
  def generate_user_id do
    "user_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  @doc """
  Generates a random avatar color.

  ## Examples
      iex> generate_avatar_color()
      "#FF5733"
  """
  @spec generate_avatar_color() :: String.t()
  def generate_avatar_color do
    colors = [
      "#FF5733", "#33FF57", "#3357FF", "#FF33F1", "#F1FF33", "#33FFF1",
      "#FF8C33", "#8C33FF", "#33FF8C", "#FF3333", "#33FF33", "#3333FF",
      "#FFFF33", "#FF33FF", "#33FFFF", "#FF6633", "#6633FF", "#33FF66",
      "#FF3366", "#3366FF", "#66FF33", "#FF9933", "#9933FF", "#33FF99"
    ]
    
    Enum.random(colors)
  end

  # Private helper functions

  defp put_default_values(changeset) do
    now = DateTime.utc_now()
    
    changeset
    |> put_change(:last_seen, now)
    |> put_change(:is_active, true)
    |> maybe_put_default_avatar_color()
  end

  defp maybe_put_default_avatar_color(changeset) do
    case get_field(changeset, :avatar_color) do
      nil ->
        put_change(changeset, :avatar_color, generate_avatar_color())
      
      _ ->
        changeset
    end
  end
end