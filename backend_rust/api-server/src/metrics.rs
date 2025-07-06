use axum::{extract::State, http::StatusCode, response::IntoResponse};
use lazy_static::lazy_static;
use prometheus::{
    register_counter, register_gauge, register_histogram, Counter, Gauge, Histogram,
    TextEncoder,
};
use std::sync::Arc;
use tokio::sync::RwLock;

// Metrics for the Rust API Server (External Coordination with Redis)
lazy_static! {
    // HTTP Request metrics
    pub static ref HTTP_REQUESTS_TOTAL: Counter = register_counter!(
        "api_server_http_requests_total",
        "Total number of HTTP requests processed"
    )
    .unwrap();

    pub static ref HTTP_REQUEST_DURATION: Histogram = register_histogram!(
        "api_server_http_request_duration_seconds",
        "HTTP request duration in seconds"
    )
    .unwrap();

    // Session metrics
    pub static ref SESSIONS_CREATED_TOTAL: Counter = register_counter!(
        "api_server_sessions_created_total",
        "Total number of sessions created"
    )
    .unwrap();

    pub static ref SESSIONS_ACTIVE: Gauge = register_gauge!(
        "api_server_sessions_active",
        "Number of currently active sessions"
    )
    .unwrap();

    // Participant metrics
    pub static ref PARTICIPANTS_JOINED_TOTAL: Counter = register_counter!(
        "api_server_participants_joined_total",
        "Total number of participants joined"
    )
    .unwrap();

    pub static ref PARTICIPANTS_LEFT_TOTAL: Counter = register_counter!(
        "api_server_participants_left_total",
        "Total number of participants left"
    )
    .unwrap();

    pub static ref PARTICIPANTS_ACTIVE: Gauge = register_gauge!(
        "api_server_participants_active_total",
        "Total number of active participants across all sessions"
    )
    .unwrap();

    // Database metrics
    pub static ref DATABASE_OPERATIONS_TOTAL: Counter = register_counter!(
        "api_server_database_operations_total",
        "Total number of database operations"
    )
    .unwrap();

    pub static ref DATABASE_OPERATION_DURATION: Histogram = register_histogram!(
        "api_server_database_operation_duration_seconds",
        "Database operation duration in seconds"
    )
    .unwrap();

    // Redis metrics (External Coordination)
    pub static ref REDIS_OPERATIONS_TOTAL: Counter = register_counter!(
        "api_server_redis_operations_total",
        "Total number of Redis operations"
    )
    .unwrap();

    pub static ref REDIS_OPERATION_DURATION: Histogram = register_histogram!(
        "api_server_redis_operation_duration_seconds",
        "Redis operation duration in seconds"
    )
    .unwrap();

    pub static ref REDIS_CONNECTIONS_ACTIVE: Gauge = register_gauge!(
        "api_server_redis_connections_active",
        "Number of active Redis connections"
    )
    .unwrap();

    // Health check metrics
    pub static ref HEALTH_CHECK_TOTAL: Counter = register_counter!(
        "api_server_health_check_total",
        "Total number of health check requests"
    )
    .unwrap();
}

/// Additional runtime metrics stored in application state
#[derive(Debug, Clone)]
pub struct RuntimeMetrics {
    pub start_time: std::time::SystemTime,
    pub request_count: Arc<RwLock<u64>>,
    pub error_count: Arc<RwLock<u64>>,
}

impl RuntimeMetrics {
    pub fn new() -> Self {
        Self {
            start_time: std::time::SystemTime::now(),
            request_count: Arc::new(RwLock::new(0)),
            error_count: Arc::new(RwLock::new(0)),
        }
    }

    pub async fn increment_requests(&self) {
        let mut count = self.request_count.write().await;
        *count += 1;
        HTTP_REQUESTS_TOTAL.inc();
    }

    pub async fn increment_errors(&self) {
        let mut count = self.error_count.write().await;
        *count += 1;
    }

    pub async fn get_request_count(&self) -> u64 {
        *self.request_count.read().await
    }

    pub async fn get_error_count(&self) -> u64 {
        *self.error_count.read().await
    }

    pub fn uptime_seconds(&self) -> f64 {
        self.start_time
            .elapsed()
            .unwrap_or_default()
            .as_secs_f64()
    }
}

/// Prometheus metrics endpoint handler
pub async fn metrics_handler(
    State(state): State<crate::AppState>,
) -> Result<impl IntoResponse, StatusCode> {
    let runtime_metrics = &state.metrics;
    // Update runtime metrics
    let request_count = runtime_metrics.get_request_count().await;
    let error_count = runtime_metrics.get_error_count().await;
    let uptime = runtime_metrics.uptime_seconds();

    // Update Prometheus gauges with current runtime values
    // Note: These could also be separate metrics, but we'll use labels or separate metrics
    
    // Collect all metrics
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    
    match encoder.encode_to_string(&metric_families) {
        Ok(output) => {
            // Add custom runtime metrics that aren't tracked by prometheus directly
            let custom_metrics = format!(
                "\n# HELP api_server_uptime_seconds Total uptime of the API server\n\
                 # TYPE api_server_uptime_seconds gauge\n\
                 api_server_uptime_seconds {}\n\
                 # HELP api_server_total_requests Total requests processed since startup\n\
                 # TYPE api_server_total_requests counter\n\
                 api_server_total_requests {}\n\
                 # HELP api_server_total_errors Total errors since startup\n\
                 # TYPE api_server_total_errors counter\n\
                 api_server_total_errors {}\n",
                uptime, request_count, error_count
            );
            
            Ok((
                StatusCode::OK,
                [("content-type", "text/plain; charset=utf-8")],
                format!("{}{}", output, custom_metrics),
            ))
        }
        Err(e) => {
            tracing::error!("Failed to encode metrics: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

/// Middleware to track HTTP request metrics
pub async fn track_request_metrics(
    State(state): State<crate::AppState>,
    request: axum::http::Request<axum::body::Body>,
    next: axum::middleware::Next,
) -> impl IntoResponse {
    let runtime_metrics = &state.metrics;
    let start_time = std::time::Instant::now();
    
    // Increment request counter
    runtime_metrics.increment_requests().await;
    
    // Process the request
    let response = next.run(request).await;
    
    // Record request duration
    let duration = start_time.elapsed().as_secs_f64();
    HTTP_REQUEST_DURATION.observe(duration);
    
    // Check if it's an error response
    if response.status().is_server_error() || response.status().is_client_error() {
        runtime_metrics.increment_errors().await;
    }
    
    response
}

/// Helper functions for specific metric tracking
pub mod tracking {
    use super::*;
    use std::time::Instant;

    pub fn track_session_created() {
        SESSIONS_CREATED_TOTAL.inc();
        SESSIONS_ACTIVE.inc();
    }

    pub fn track_session_ended() {
        SESSIONS_ACTIVE.dec();
    }

    pub fn track_participant_joined() {
        PARTICIPANTS_JOINED_TOTAL.inc();
        PARTICIPANTS_ACTIVE.inc();
    }

    pub fn track_participant_left() {
        PARTICIPANTS_LEFT_TOTAL.inc();
        PARTICIPANTS_ACTIVE.dec();
    }

    pub fn track_health_check() {
        HEALTH_CHECK_TOTAL.inc();
    }

    /// Track a database operation
    pub async fn track_database_operation<F, T>(operation: F) -> T
    where
        F: std::future::Future<Output = T>,
    {
        let start = Instant::now();
        DATABASE_OPERATIONS_TOTAL.inc();
        
        let result = operation.await;
        
        let duration = start.elapsed().as_secs_f64();
        DATABASE_OPERATION_DURATION.observe(duration);
        
        result
    }

    /// Track a Redis operation
    pub async fn track_redis_operation<F, T>(operation: F) -> T
    where
        F: std::future::Future<Output = T>,
    {
        let start = Instant::now();
        REDIS_OPERATIONS_TOTAL.inc();
        
        let result = operation.await;
        
        let duration = start.elapsed().as_secs_f64();
        REDIS_OPERATION_DURATION.observe(duration);
        
        result
    }

    pub fn set_redis_connections(count: i64) {
        REDIS_CONNECTIONS_ACTIVE.set(count as f64);
    }
}