use axum::{
    extract::State,
    routing::{delete, get, post},
    Json, Router,
};
use shared::{AppConfig, AppResult};
use sqlx::PgPool;
use std::sync::Arc;
use tower::ServiceBuilder;
use tower_http::trace::TraceLayer;
use tracing::{info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod config;
mod database;
mod error;
mod handlers;
mod middleware;
mod models;

use database::postgres::create_pool;
use error::handle_error;
use handlers::{participants, sessions};
use serde_json::json;
use middleware::cors::cors_layer;

/// Application state shared across all handlers
#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub config: Arc<AppConfig>,
}

#[tokio::main]
async fn main() -> AppResult<()> {
    // Load environment variables from .env file if present
    dotenvy::dotenv().ok();

    // Load application configuration
    let config = Arc::new(AppConfig::load().map_err(|e| {
        eprintln!("Failed to load configuration: {}", e);
        std::process::exit(1);
    }).unwrap());

    // Validate configuration
    if let Err(e) = config.validate() {
        eprintln!("Invalid configuration: {}", e);
        std::process::exit(1);
    }

    // Initialize logging
    init_logging(&config)?;

    info!("Starting API server with configuration: {}", config);

    // Create database connection pool
    let db = create_pool(&config).await?;

    // Run database migrations
    info!("Running database migrations...");
    match sqlx::migrate!("../migrations").run(&db).await {
        Ok(_) => info!("Database migrations completed successfully"),
        Err(e) => {
            warn!("Migration check: {}", e);
            // Don't fail if migrations have already been applied
            if !e.to_string().contains("already exists") {
                return Err(e.into());
            }
            info!("Database schema already up to date");
        }
    }

    // Create application state
    let state = AppState {
        db,
        config: Arc::clone(&config),
    };

    // Build the application router
    let app = create_router(state).await?;

    // Create server address
    let addr = config.api_address();
    info!("API server listening on {}", addr);

    // Start the server
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    info!("API server shutdown complete");
    Ok(())
}

/// Health check endpoint
async fn health_check(State(state): State<AppState>) -> Result<Json<serde_json::Value>, error::ApiError> {
    // Check database connection
    database::postgres::health_check(&state.db).await.map_err(error::ApiError)?;
    
    let response = json!({
        "status": "healthy",
        "timestamp": chrono::Utc::now(),
        "service": "api-server",
        "version": env!("CARGO_PKG_VERSION")
    });
    
    Ok(Json(response))
}

/// Create the main application router with all routes and middleware
async fn create_router(state: AppState) -> AppResult<Router> {
    let api_routes = Router::new()
        // Health check route
        .route("/health", get(health_check))
        // Session management routes
        .route("/sessions", post(sessions::create_session))
        .route("/sessions/:session_id", get(sessions::get_session))
        .route("/sessions/:session_id", delete(sessions::end_session))
        .route("/sessions/:session_id/join", post(sessions::join_session))
        // Participant management routes
        .route(
            "/sessions/:session_id/participants",
            get(participants::list_participants),
        )
        .route(
            "/sessions/:session_id/participants/:user_id",
            delete(participants::leave_session),
        )
        .with_state(state.clone());

    // Add root health check as well
    let root_routes = Router::new()
        .route("/health", get(health_check))
        .with_state(state.clone());

    let app = Router::new()
        .merge(root_routes)
        .nest("/api", api_routes)
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors_layer(&state.config))
                .into_inner(),
        )
        .fallback(handle_error);

    Ok(app)
}

/// Initialize structured logging
fn init_logging(config: &AppConfig) -> AppResult<()> {
    let log_level = config.app.log_level.parse().unwrap_or(tracing::Level::INFO);

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("api_server={},tower_http=debug", log_level).into()),
        )
        .with(tracing_subscriber::fmt::layer().with_target(false))
        .init();

    Ok(())
}

/// Graceful shutdown signal handler
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {
            info!("Received Ctrl+C, initiating graceful shutdown");
        },
        _ = terminate => {
            info!("Received SIGTERM, initiating graceful shutdown");
        },
    }
}