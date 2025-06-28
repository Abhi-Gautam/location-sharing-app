defmodule LocationSharing.Factory do
  @moduledoc """
  Factory for creating test data.
  """

  alias LocationSharing.Repo
  alias LocationSharing.Sessions.{Session, Participant}

  def build(:session) do
    %Session{
      id: Ecto.UUID.generate(),
      name: "Test Session #{System.unique_integer([:positive])}",
      creator_id: Ecto.UUID.generate(),
      is_active: true,
      last_activity: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), 24 * 3600, :second),
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def build(:session, attrs) do
    build(:session)
    |> struct!(attrs)
  end

  def build(:participant) do
    %Participant{
      id: Ecto.UUID.generate(),
      session_id: Ecto.UUID.generate(),
      user_id: "user_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}",
      display_name: "User #{System.unique_integer([:positive])}",
      avatar_color: "#FF5733",
      last_seen: DateTime.utc_now(),
      is_active: true,
      joined_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def build(:participant, attrs) do
    build(:participant)
    |> struct!(attrs)
  end

  def build(factory_name, attrs) do
    factory_name |> build() |> struct!(attrs)
  end

  def insert!(factory_name, attrs \\ []) do
    factory_name |> build(attrs) |> Repo.insert!()
  end

  def insert(factory_name, attrs \\ []) do
    case Repo.insert(build(factory_name, attrs)) do
      {:ok, record} -> record
      {:error, changeset} -> raise "Failed to insert #{factory_name}: #{inspect(changeset.errors)}"
    end
  end

  # Convenience function for participant with session
  def insert_participant_with_session(participant_attrs \\ [], session_attrs \\ []) do
    session = insert(:session, session_attrs)
    participant_attrs = Keyword.put(participant_attrs, :session_id, session.id)
    participant = insert(:participant, participant_attrs)
    %{participant | session: session}
  end
end