use axum::http::{HeaderValue, Method};
use shared::AppConfig;
use tower_http::cors::{Any, CorsLayer};

/// Create CORS layer with configuration-based allowed origins
pub fn cors_layer(config: &AppConfig) -> CorsLayer {
    let mut cors = CorsLayer::new()
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
        .allow_headers(Any)
        .allow_credentials(true);

    // Configure allowed origins based on environment
    if config.is_development() {
        // In development, allow common local development origins
        cors = cors
            .allow_origin("http://localhost:3000".parse::<HeaderValue>().unwrap())
            .allow_origin("http://localhost:8080".parse::<HeaderValue>().unwrap())
            .allow_origin("http://127.0.0.1:3000".parse::<HeaderValue>().unwrap())
            .allow_origin("http://127.0.0.1:8080".parse::<HeaderValue>().unwrap());
        
        // Also allow configured origins
        for origin in &config.server.cors_allowed_origins {
            if let Ok(header_value) = origin.parse::<HeaderValue>() {
                cors = cors.allow_origin(header_value);
            }
        }
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