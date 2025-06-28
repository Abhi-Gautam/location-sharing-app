use redis::{
    aio::{ConnectionManager, PubSub},
    AsyncCommands, RedisResult,
};
use shared::{AppResult, Constants, Location, RedisKeys};
use serde_json;
use tracing::{debug, info};
use uuid::Uuid;

/// Redis client for WebSocket server operations
#[derive(Clone)]
pub struct RedisClient {
    connection: ConnectionManager,
}

impl RedisClient {
    /// Create a new Redis client
    pub async fn new(redis_url: &str) -> AppResult<Self> {
        info!("Connecting to Redis...");
        
        let client = redis::Client::open(redis_url)?;
        let connection = ConnectionManager::new(client).await?;
        
        info!("Successfully connected to Redis");
        Ok(Self { connection })
    }

    /// Store location data with TTL
    pub async fn store_location(
        &self,
        session_id: &Uuid,
        user_id: &str,
        location: &Location,
    ) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::location(session_id, user_id);
        let value = serde_json::to_string(location)?;
        
        // Store location with TTL
        conn.set_ex(&key, &value, Constants::LOCATION_TTL_SECONDS as u64).await?;
        
        debug!("Stored location for user {} in session {}", user_id, session_id);
        Ok(())
    }

    /// Get location data for a user
    pub async fn get_location(
        &self,
        session_id: &Uuid,
        user_id: &str,
    ) -> AppResult<Option<Location>> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::location(session_id, user_id);
        
        let value: Option<String> = conn.get(&key).await?;
        
        match value {
            Some(data) => {
                let location: Location = serde_json::from_str(&data)?;
                Ok(Some(location))
            }
            None => Ok(None),
        }
    }

    /// Get all locations for a session
    pub async fn get_session_locations(
        &self,
        session_id: &Uuid,
    ) -> AppResult<Vec<(String, Location)>> {
        let mut conn = self.connection.clone();
        let pattern = format!("locations:{}:*", session_id);
        
        let keys: Vec<String> = conn.keys(&pattern).await?;
        let mut locations = Vec::new();
        
        for key in keys {
            if let Ok(Some(value)) = conn.get::<_, Option<String>>(&key).await {
                if let Ok(location) = serde_json::from_str::<Location>(&value) {
                    // Extract user_id from key (format: locations:{session_id}:{user_id})
                    if let Some(user_id) = key.split(':').nth(2) {
                        locations.push((user_id.to_string(), location));
                    }
                }
            }
        }
        
        Ok(locations)
    }

    /// Add user to session participants set
    pub async fn add_to_session_participants(
        &self,
        session_id: &Uuid,
        user_id: &str,
    ) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::session_participants(session_id);
        
        conn.sadd(&key, user_id).await?;
        
        debug!("Added user {} to session {} participants", user_id, session_id);
        Ok(())
    }

    /// Remove user from session participants set
    pub async fn remove_from_session_participants(
        &self,
        session_id: &Uuid,
        user_id: &str,
    ) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::session_participants(session_id);
        
        conn.srem(&key, user_id).await?;
        
        debug!("Removed user {} from session {} participants", user_id, session_id);
        Ok(())
    }

    /// Get all participants for a session
    pub async fn get_session_participants(&self, session_id: &Uuid) -> AppResult<Vec<String>> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::session_participants(session_id);
        
        let participants: Vec<String> = conn.smembers(&key).await?;
        Ok(participants)
    }

    /// Set connection mapping for a user
    pub async fn set_connection(&self, user_id: &str, session_id: &Uuid) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::connection(user_id);
        
        conn.set(&key, session_id.to_string()).await?;
        
        debug!("Set connection mapping for user {} to session {}", user_id, session_id);
        Ok(())
    }

    /// Remove connection mapping for a user
    pub async fn remove_connection(&self, user_id: &str) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::connection(user_id);
        
        conn.del(&key).await?;
        
        debug!("Removed connection mapping for user {}", user_id);
        Ok(())
    }

    /// Update session activity timestamp
    pub async fn update_session_activity(&self, session_id: &Uuid) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let key = RedisKeys::session_activity(session_id);
        let timestamp = chrono::Utc::now().timestamp();
        
        conn.set(&key, timestamp).await?;
        
        debug!("Updated activity for session {}", session_id);
        Ok(())
    }

    /// Publish message to session channel
    pub async fn publish_to_session(
        &self,
        session_id: &Uuid,
        message: &str,
    ) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let channel = RedisKeys::session_channel(session_id);
        
        conn.publish(&channel, message).await?;
        
        debug!("Published message to session {} channel", session_id);
        Ok(())
    }

    /// Subscribe to session channels for pub/sub  
    pub async fn subscribe_to_sessions(&self) -> AppResult<PubSub> {
        // Create a new connection for pub/sub since ConnectionManager doesn't support it
        let client = redis::Client::open("redis://localhost:6379")?; // TODO: Get this from config
        let conn = client.get_async_connection().await?;
        let mut pubsub = conn.into_pubsub();
        
        // Subscribe to all session channels using pattern
        pubsub.psubscribe("channel:session:*").await?;
        
        info!("Subscribed to session channels");
        Ok(pubsub)
    }

    /// Clean up expired location data
    pub async fn cleanup_expired_locations(&self) -> AppResult<usize> {
        let mut conn = self.connection.clone();
        let pattern = "locations:*";
        
        let keys: Vec<String> = conn.keys(&pattern).await?;
        let mut cleaned_count = 0;
        
        for key in keys {
            // Check if key exists (it will be automatically expired by Redis TTL)
            let exists: bool = conn.exists(&key).await?;
            if !exists {
                cleaned_count += 1;
            }
        }
        
        if cleaned_count > 0 {
            debug!("Cleaned up {} expired location entries", cleaned_count);
        }
        
        Ok(cleaned_count)
    }

    /// Get Redis connection health status
    pub async fn health_check(&self) -> AppResult<()> {
        let mut conn = self.connection.clone();
        let _: String = redis::cmd("PING").query_async(&mut conn).await?;
        Ok(())
    }

    /// Get Redis statistics
    pub async fn get_stats(&self) -> AppResult<RedisStats> {
        let mut conn = self.connection.clone();
        
        // Count active locations
        let location_keys: Vec<String> = conn.keys("locations:*").await?;
        let active_locations = location_keys.len();
        
        // Count active sessions
        let session_keys: Vec<String> = conn.keys("session_participants:*").await?;
        let active_sessions = session_keys.len();
        
        // Count active connections
        let connection_keys: Vec<String> = conn.keys("connections:*").await?;
        let active_connections = connection_keys.len();
        
        Ok(RedisStats {
            active_locations,
            active_sessions,
            active_connections,
        })
    }
}

/// Redis statistics
#[derive(Debug)]
pub struct RedisStats {
    pub active_locations: usize,
    pub active_sessions: usize,
    pub active_connections: usize,
}

