use thiserror::Error;

/// Application-wide error types for comprehensive error handling
#[derive(Error, Debug)]
pub enum AppError {
    /// Database-related errors
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    /// Redis-related errors
    #[error("Redis error: {0}")]
    Redis(#[from] redis::RedisError),
    
    /// JSON serialization/deserialization errors
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    
    /// JWT token errors
    #[error("JWT error: {0}")]
    Jwt(#[from] jsonwebtoken::errors::Error),
    
    /// UUID parsing errors
    #[error("UUID error: {0}")]
    Uuid(#[from] uuid::Error),
    
    /// Configuration errors
    #[error("Configuration error: {0}")]
    Config(#[from] config::ConfigError),
    
    /// Session-specific errors
    #[error("Session not found")]
    SessionNotFound,
    
    #[error("Session expired")]
    SessionExpired,
    
    #[error("Session inactive")]
    SessionInactive,
    
    #[error("Session capacity exceeded (max {max} participants)")]
    SessionCapacityExceeded { max: usize },
    
    #[error("Unauthorized session operation")]
    UnauthorizedSessionOperation,
    
    /// Participant-specific errors
    #[error("Participant not found")]
    ParticipantNotFound,
    
    #[error("Participant already exists")]
    ParticipantAlreadyExists,
    
    #[error("Invalid participant data: {message}")]
    InvalidParticipantData { message: String },
    
    /// Authentication and authorization errors
    #[error("Invalid or missing authentication token")]
    InvalidToken,
    
    #[error("Token expired")]
    TokenExpired,
    
    #[error("Insufficient permissions")]
    InsufficientPermissions,
    
    /// Input validation errors
    #[error("Validation error: {field} - {message}")]
    Validation { field: String, message: String },
    
    #[error("Invalid request format")]
    InvalidRequest,
    
    /// WebSocket-specific errors
    #[error("WebSocket connection error: {0}")]
    WebSocket(String),
    
    #[error("Invalid WebSocket message format")]
    InvalidWebSocketMessage,
    
    /// Location-related errors
    #[error("Invalid location data: {message}")]
    InvalidLocation { message: String },
    
    #[error("Location update failed")]
    LocationUpdateFailed,
    
    /// I/O errors
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
    
    /// Migration errors
    #[error("Migration error: {0}")]
    Migration(#[from] sqlx::migrate::MigrateError),
    
    /// Generic internal errors
    #[error("Internal server error: {0}")]
    Internal(#[from] anyhow::Error),
    
    #[error("Service unavailable: {service}")]
    ServiceUnavailable { service: String },
    
    #[error("Rate limit exceeded")]
    RateLimitExceeded,
}

impl AppError {
    /// Create a validation error with field and message
    pub fn validation(field: &str, message: &str) -> Self {
        Self::Validation {
            field: field.to_string(),
            message: message.to_string(),
        }
    }
    
    /// Create an invalid participant data error
    pub fn invalid_participant_data(message: &str) -> Self {
        Self::InvalidParticipantData {
            message: message.to_string(),
        }
    }
    
    /// Create an invalid location error
    pub fn invalid_location(message: &str) -> Self {
        Self::InvalidLocation {
            message: message.to_string(),
        }
    }
    
    /// Create a WebSocket error
    pub fn websocket(message: &str) -> Self {
        Self::WebSocket(message.to_string())
    }
    
    /// Create a service unavailable error
    pub fn service_unavailable(service: &str) -> Self {
        Self::ServiceUnavailable {
            service: service.to_string(),
        }
    }
    
    /// Check if error is client-side (4xx status code equivalent)
    pub fn is_client_error(&self) -> bool {
        matches!(
            self,
            Self::SessionNotFound
                | Self::SessionExpired
                | Self::SessionInactive
                | Self::SessionCapacityExceeded { .. }
                | Self::UnauthorizedSessionOperation
                | Self::ParticipantNotFound
                | Self::ParticipantAlreadyExists
                | Self::InvalidParticipantData { .. }
                | Self::InvalidToken
                | Self::TokenExpired
                | Self::InsufficientPermissions
                | Self::Validation { .. }
                | Self::InvalidRequest
                | Self::InvalidWebSocketMessage
                | Self::InvalidLocation { .. }
                | Self::RateLimitExceeded
        )
    }
    
    /// Get appropriate HTTP status code for this error
    pub fn status_code(&self) -> u16 {
        match self {
            Self::SessionNotFound | Self::ParticipantNotFound => 404,
            Self::SessionExpired | Self::SessionInactive => 410, // Gone
            Self::SessionCapacityExceeded { .. } => 409, // Conflict
            Self::UnauthorizedSessionOperation | Self::InsufficientPermissions => 403,
            Self::ParticipantAlreadyExists => 409, // Conflict
            Self::InvalidToken | Self::TokenExpired => 401,
            Self::Validation { .. } | Self::InvalidRequest | Self::InvalidParticipantData { .. } | Self::InvalidLocation { .. } => 400,
            Self::RateLimitExceeded => 429,
            Self::ServiceUnavailable { .. } => 503,
            _ => 500, // Internal server error
        }
    }
    
    /// Get error code for client communication
    pub fn error_code(&self) -> &'static str {
        match self {
            Self::SessionNotFound => "SESSION_NOT_FOUND",
            Self::SessionExpired => "SESSION_EXPIRED",
            Self::SessionInactive => "SESSION_INACTIVE",
            Self::SessionCapacityExceeded { .. } => "SESSION_CAPACITY_EXCEEDED",
            Self::UnauthorizedSessionOperation => "UNAUTHORIZED_SESSION_OPERATION",
            Self::ParticipantNotFound => "PARTICIPANT_NOT_FOUND",
            Self::ParticipantAlreadyExists => "PARTICIPANT_ALREADY_EXISTS",
            Self::InvalidParticipantData { .. } => "INVALID_PARTICIPANT_DATA",
            Self::InvalidToken => "INVALID_TOKEN",
            Self::TokenExpired => "TOKEN_EXPIRED",
            Self::InsufficientPermissions => "INSUFFICIENT_PERMISSIONS",
            Self::Validation { .. } => "VALIDATION_ERROR",
            Self::InvalidRequest => "INVALID_REQUEST",
            Self::InvalidWebSocketMessage => "INVALID_WEBSOCKET_MESSAGE",
            Self::InvalidLocation { .. } => "INVALID_LOCATION",
            Self::LocationUpdateFailed => "LOCATION_UPDATE_FAILED",
            Self::RateLimitExceeded => "RATE_LIMIT_EXCEEDED",
            Self::ServiceUnavailable { .. } => "SERVICE_UNAVAILABLE",
            _ => "INTERNAL_ERROR",
        }
    }
}

/// Result type alias for application operations
pub type AppResult<T> = Result<T, AppError>;