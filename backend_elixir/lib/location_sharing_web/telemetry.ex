defmodule LocationSharingWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("location_sharing.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("location_sharing.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("location_sharing.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("location_sharing.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("location_sharing.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # SessionServer Metrics (BEAM Process Architecture)
      counter("location_sharing.session_server.started.count",
        description: "Number of session servers started"
      ),
      counter("location_sharing.session_server.terminated.count",
        description: "Number of session servers terminated"
      ),
      summary("location_sharing.session_server.terminated.uptime",
        unit: {:native, :second},
        description: "Session server uptime before termination"
      ),
      counter("location_sharing.session_server.participant_joined.count",
        description: "Number of participants joined sessions"
      ),
      summary("location_sharing.session_server.participant_joined.total_participants",
        description: "Total participants in session when someone joins"
      ),
      counter("location_sharing.session_server.participant_left.count",
        description: "Number of participants left sessions"
      ),
      summary("location_sharing.session_server.participant_left.total_participants",
        description: "Total participants remaining in session"
      ),
      counter("location_sharing.session_server.location_updated.count",
        description: "Number of location updates processed"
      ),

      # Periodic SessionServer Metrics
      last_value("location_sharing.session_servers.active.count",
        description: "Number of active session servers"
      ),
      last_value("location_sharing.session_servers.active.total_participants",
        description: "Total participants across all active sessions"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {__MODULE__, :measure_session_servers, []}
    ]
  end

  @doc """
  Periodic measurement function to collect SessionServer metrics.
  """
  def measure_session_servers do
    # Count active session servers
    session_count = 
      LocationSharing.Sessions.Registry
      |> Registry.count()

    # Get total participants across all sessions
    total_participants = 
      Registry.select(LocationSharing.Sessions.Registry, [{{:"$1", :"$2", :"$3"}, [], [:"$2"]}])
      |> Enum.map(fn pid ->
        try do
          case GenServer.call(pid, :get_stats) do
            {:ok, stats} -> stats.participant_count
            _ -> 0
          end
        rescue
          _ -> 0
        end
      end)
      |> Enum.sum()

    # Emit metrics
    :telemetry.execute(
      [:location_sharing, :session_servers, :active],
      %{count: session_count, total_participants: total_participants},
      %{}
    )
  end
end
