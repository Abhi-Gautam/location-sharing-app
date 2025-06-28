use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use shared::AppError;
use tracing::{error, warn};

/// Handle application errors and convert them to HTTP responses
pub async fn handle_error() -> Response {
    let error_response = json!({
        "error": {
            "code": "NOT_FOUND",
            "message": "The requested resource was not found"
        }
    });

    (StatusCode::NOT_FOUND, Json(error_response)).into_response()
}

/// Wrapper for AppError to work around orphan rules
#[derive(Debug)]
pub struct ApiError(pub AppError);

impl From<AppError> for ApiError {
    fn from(error: AppError) -> Self {
        ApiError(error)
    }
}

/// Convert ApiError to HTTP response
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status_code = StatusCode::from_u16(self.0.status_code()).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
        
        // Log errors based on severity
        match status_code {
            StatusCode::INTERNAL_SERVER_ERROR | StatusCode::SERVICE_UNAVAILABLE => {
                error!("Server error: {}", self.0);
            }
            StatusCode::BAD_REQUEST | StatusCode::UNPROCESSABLE_ENTITY => {
                warn!("Client error: {}", self.0);
            }
            _ => {
                // Log other errors as debug/info level
                tracing::debug!("Request error: {}", self.0);
            }
        }

        let error_response = json!({
            "error": {
                "code": self.0.error_code(),
                "message": self.0.to_string()
            }
        });

        (status_code, Json(error_response)).into_response()
    }
}