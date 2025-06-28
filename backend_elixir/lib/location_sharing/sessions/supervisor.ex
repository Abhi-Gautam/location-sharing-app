defmodule LocationSharing.Sessions.Supervisor do
  @moduledoc """
  Supervisor for session-related processes.

  This supervisor manages:
  - Session cleanup worker
  - Dynamic session servers
  - Session registry
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Registry for session processes
      {Registry, keys: :unique, name: LocationSharing.Sessions.Registry},
      
      # Dynamic supervisor for session servers
      {DynamicSupervisor, name: LocationSharing.Sessions.DynamicSupervisor, strategy: :one_for_one},
      
      # Session cleanup worker
      LocationSharing.Sessions.CleanupWorker
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end