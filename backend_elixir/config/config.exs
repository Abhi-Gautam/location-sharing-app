# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :location_sharing,
  ecto_repos: [LocationSharing.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :location_sharing, LocationSharingWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: LocationSharingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LocationSharing.PubSub,
  live_view: [signing_salt: "gkkp7i5w"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :location_sharing, LocationSharing.Mailer, adapter: Swoosh.Adapters.Local

# Redis configuration
config :location_sharing, LocationSharing.Redis,
  host: "localhost",
  port: 6379,
  database: 0

# Guardian JWT configuration
config :location_sharing, LocationSharing.Guardian,
  issuer: "location_sharing",
  secret_key: "your-guardian-secret-key-change-in-production"

# CORS configuration
config :cors_plug,
  origin: ["*"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
