use axum::http::{HeaderValue, Method, header};
use shared::AppConfig;
use tower_http::cors::{Any, CorsLayer};

/// Create CORS layer with configuration-based allowed origins
pub fn cors_layer(config: &AppConfig) -> CorsLayer {
    let mut cors = CorsLayer::new()
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
        .allow_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
            header::ACCEPT,
            header::ORIGIN,
        ]);

    // Configure allowed origins based on environment
    if config.is_development() {
        // In development, allow any origin (no credentials for Any origin)
        cors = cors.allow_origin(Any);
    } else {
        // In production, only allow configured origins
        let origins: Result<Vec<HeaderValue>, _> = config
            .server
            .cors_allowed_origins
            .iter()
            .map(|origin| origin.parse::<HeaderValue>())
            .collect();
            
        match origins {
            Ok(origins) => {
                for origin in origins {
                    cors = cors.allow_origin(origin);
                }
            }
            Err(_) => {
                // Fallback to no CORS if origins are invalid
                tracing::warn!("Invalid CORS origins configured, disabling CORS");
                return CorsLayer::new().allow_origin(Any);
            }
        }
    }

    cors
}