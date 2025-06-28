use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

/// Session model representing a location sharing session
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Session {
    pub id: Uuid,
    pub name: Option<String>,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub creator_id: Uuid,
    pub is_active: bool,
    pub last_activity: DateTime<Utc>,
}

/// Participant model representing a user in a session
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Participant {
    pub id: Uuid,
    pub session_id: Uuid,
    pub user_id: String,
    pub display_name: String,
    pub avatar_color: String,
    pub joined_at: DateTime<Utc>,
    pub last_seen: DateTime<Utc>,
    pub is_active: bool,
}

/// Location data for real-time tracking
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Location {
    pub lat: f64,
    pub lng: f64,
    pub accuracy: f64,
    pub timestamp: DateTime<Utc>,
}

/// Request DTOs for API endpoints

#[derive(Debug, Deserialize)]
pub struct CreateSessionRequest {
    pub name: Option<String>,
    #[serde(default = "default_expires_in_minutes")]
    pub expires_in_minutes: i64,
}

fn default_expires_in_minutes() -> i64 {
    1440 // 24 hours
}

#[derive(Debug, Deserialize)]
pub struct JoinSessionRequest {
    pub display_name: String,
    pub avatar_color: Option<String>,
}

/// Response DTOs for API endpoints

#[derive(Debug, Serialize)]
pub struct CreateSessionResponse {
    pub session_id: Uuid,
    pub join_link: String,
    pub expires_at: DateTime<Utc>,
    pub name: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SessionDetailsResponse {
    pub id: Uuid,
    pub name: Option<String>,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub participant_count: i64,
    pub is_active: bool,
}

#[derive(Debug, Serialize)]
pub struct JoinSessionResponse {
    pub user_id: Uuid,
    pub websocket_token: String,
    pub websocket_url: String,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ParticipantResponse {
    pub user_id: String,
    pub display_name: String,
    pub avatar_color: String,
    pub last_seen: DateTime<Utc>,
    pub is_active: bool,
}

#[derive(Debug, Serialize)]
pub struct ParticipantsListResponse {
    pub participants: Vec<ParticipantResponse>,
}

#[derive(Debug, Serialize)]
pub struct SuccessResponse {
    pub success: bool,
}

/// WebSocket message types

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum WebSocketMessage {
    #[serde(rename = "location_update")]
    LocationUpdate(LocationUpdateData),
    #[serde(rename = "ping")]
    Ping,
    #[serde(rename = "participant_joined")]
    ParticipantJoined(ParticipantJoinedData),
    #[serde(rename = "participant_left")]
    ParticipantLeft(ParticipantLeftData),
    #[serde(rename = "location_broadcast")]
    LocationBroadcast(LocationBroadcastData),
    #[serde(rename = "session_ended")]
    SessionEnded(SessionEndedData),
    #[serde(rename = "pong")]
    Pong,
    #[serde(rename = "error")]
    Error(ErrorData),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocationUpdateData {
    pub lat: f64,
    pub lng: f64,
    pub accuracy: f64,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParticipantJoinedData {
    pub user_id: String,
    pub display_name: String,
    pub avatar_color: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParticipantLeftData {
    pub user_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocationBroadcastData {
    pub user_id: String,
    pub lat: f64,
    pub lng: f64,
    pub accuracy: f64,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionEndedData {
    pub reason: String, // "expired" or "ended_by_creator"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorData {
    pub code: String,
    pub message: String,
}

/// JWT Claims for WebSocket authentication
#[derive(Debug, Serialize, Deserialize)]
pub struct JwtClaims {
    pub sub: String,      // user_id
    pub session_id: Uuid, // session UUID
    pub exp: i64,         // expiration timestamp
    pub iat: i64,         // issued at timestamp
}

/// Redis key builders for consistent key naming
pub struct RedisKeys;

impl RedisKeys {
    /// Key for storing location data: locations:{session_id}:{user_id}
    pub fn location(session_id: &Uuid, user_id: &str) -> String {
        format!("locations:{}:{}", session_id, user_id)
    }
    
    /// Key for storing active session participants: session_participants:{session_id}
    pub fn session_participants(session_id: &Uuid) -> String {
        format!("session_participants:{}", session_id)
    }
    
    /// Key for WebSocket connection mapping: connections:{user_id}
    pub fn connection(user_id: &str) -> String {
        format!("connections:{}", user_id)
    }
    
    /// Key for session activity tracking: session_activity:{session_id}
    pub fn session_activity(session_id: &Uuid) -> String {
        format!("session_activity:{}", session_id)
    }
    
    /// Channel for pub/sub messaging: channel:session:{session_id}
    pub fn session_channel(session_id: &Uuid) -> String {
        format!("channel:session:{}", session_id)
    }
}

/// Constants for application configuration
pub struct Constants;

impl Constants {
    /// Maximum number of participants per session
    pub const MAX_PARTICIPANTS_PER_SESSION: usize = 50;
    
    /// Location data TTL in Redis (30 seconds)
    pub const LOCATION_TTL_SECONDS: usize = 30;
    
    /// Default session duration (24 hours)
    pub const DEFAULT_SESSION_DURATION_MINUTES: i64 = 1440;
    
    /// Session auto-expire duration (1 hour of inactivity)
    pub const SESSION_AUTO_EXPIRE_MINUTES: i64 = 60;
    
    /// WebSocket JWT token duration (24 hours)
    pub const WS_TOKEN_DURATION_HOURS: i64 = 24;
    
    /// Default avatar colors for participants
    pub const DEFAULT_AVATAR_COLORS: &'static [&'static str] = &[
        "#FF5733", "#33FF57", "#3357FF", "#FF33F5", "#F5FF33",
        "#33FFF5", "#F533FF", "#FF8C33", "#8CFF33", "#338CFF",
    ];
}

/// Validation helpers
impl CreateSessionRequest {
    pub fn validate(&self) -> Result<(), String> {
        if let Some(name) = &self.name {
            if name.trim().is_empty() {
                return Err("Session name cannot be empty".to_string());
            }
            if name.len() > 255 {
                return Err("Session name cannot exceed 255 characters".to_string());
            }
        }
        
        if self.expires_in_minutes <= 0 {
            return Err("Session duration must be positive".to_string());
        }
        
        if self.expires_in_minutes > 10080 { // 7 days
            return Err("Session duration cannot exceed 7 days".to_string());
        }
        
        Ok(())
    }
}

impl JoinSessionRequest {
    pub fn validate(&self) -> Result<(), String> {
        if self.display_name.trim().is_empty() {
            return Err("Display name cannot be empty".to_string());
        }
        
        if self.display_name.len() > 100 {
            return Err("Display name cannot exceed 100 characters".to_string());
        }
        
        if let Some(color) = &self.avatar_color {
            if !color.starts_with('#') || color.len() != 7 {
                return Err("Avatar color must be a valid hex color (e.g., #FF5733)".to_string());
            }
        }
        
        Ok(())
    }
}

impl LocationUpdateData {
    pub fn validate(&self) -> Result<(), String> {
        if self.lat < -90.0 || self.lat > 90.0 {
            return Err("Latitude must be between -90 and 90 degrees".to_string());
        }
        
        if self.lng < -180.0 || self.lng > 180.0 {
            return Err("Longitude must be between -180 and 180 degrees".to_string());
        }
        
        if self.accuracy < 0.0 {
            return Err("Accuracy must be non-negative".to_string());
        }
        
        // Check timestamp is not too far in the future (allow 5 minutes)
        let now = Utc::now();
        let future_threshold = now + chrono::Duration::minutes(5);
        if self.timestamp > future_threshold {
            return Err("Timestamp cannot be in the future".to_string());
        }
        
        // Check timestamp is not too old (allow 1 hour)
        let past_threshold = now - chrono::Duration::hours(1);
        if self.timestamp < past_threshold {
            return Err("Timestamp is too old".to_string());
        }
        
        Ok(())
    }
}