/// Shared library for location sharing application
/// 
/// This library provides common types, error handling, and utilities
/// used across both the API server and WebSocket server components.

pub mod types;
pub mod error;
pub mod utils;
pub mod config;

// Re-export commonly used types
pub use types::*;
pub use error::*;
pub use utils::*;
pub use config::*;

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn test_create_session_request_validation() {
        let valid_request = CreateSessionRequest {
            name: Some("Test Session".to_string()),
            expires_in_minutes: 60,
        };
        assert!(valid_request.validate().is_ok());

        let invalid_request = CreateSessionRequest {
            name: Some("".to_string()),
            expires_in_minutes: 0,
        };
        assert!(invalid_request.validate().is_err());
    }

    #[test]
    fn test_join_session_request_validation() {
        let valid_request = JoinSessionRequest {
            display_name: "John Doe".to_string(),
            avatar_color: Some("#FF5733".to_string()),
        };
        assert!(valid_request.validate().is_ok());

        let invalid_request = JoinSessionRequest {
            display_name: "".to_string(),
            avatar_color: Some("invalid-color".to_string()),
        };
        assert!(invalid_request.validate().is_err());
    }

    #[test]
    fn test_location_update_validation() {
        let valid_location = LocationUpdateData {
            lat: 37.7749,
            lng: -122.4194,
            accuracy: 5.0,
            timestamp: Utc::now(),
        };
        assert!(valid_location.validate().is_ok());

        let invalid_location = LocationUpdateData {
            lat: 91.0, // Invalid latitude
            lng: -122.4194,
            accuracy: -1.0, // Invalid accuracy
            timestamp: Utc::now(),
        };
        assert!(invalid_location.validate().is_err());
    }

    #[test]
    fn test_redis_keys() {
        let session_id = uuid::Uuid::new_v4();
        let user_id = "test-user";

        assert_eq!(
            RedisKeys::location(&session_id, user_id),
            format!("locations:{}:{}", session_id, user_id)
        );

        assert_eq!(
            RedisKeys::session_participants(&session_id),
            format!("session_participants:{}", session_id)
        );

        assert_eq!(
            RedisKeys::session_channel(&session_id),
            format!("channel:session:{}", session_id)
        );
    }

    #[test]
    fn test_error_types() {
        let error = AppError::SessionNotFound;
        assert_eq!(error.status_code(), 404);
        assert_eq!(error.error_code(), "SESSION_NOT_FOUND");
        assert!(error.is_client_error());

        let error = AppError::Internal(anyhow::anyhow!("Test internal error"));
        assert_eq!(error.status_code(), 500);
        assert!(!error.is_client_error());
    }
}