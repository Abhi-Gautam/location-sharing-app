defmodule LocationSharingWeb.Router do
  use LocationSharingWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoints (no authentication required)
  scope "/", LocationSharingWeb do
    pipe_through :api
    
    # Basic health checks
    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :detailed
    
    # Kubernetes health checks
    get "/health/ready", HealthController, :ready
    get "/health/live", HealthController, :live
  end

  scope "/api", LocationSharingWeb do
    pipe_through :api
    
    # Session management endpoints
    post "/sessions", SessionController, :create
    get "/sessions/:id", SessionController, :show
    delete "/sessions/:id", SessionController, :delete
    
    # Participant management endpoints
    post "/sessions/:session_id/join", ParticipantController, :join
    delete "/sessions/:session_id/participants/:user_id", ParticipantController, :leave
    get "/sessions/:session_id/participants", ParticipantController, :list
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:location_sharing, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: LocationSharingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
