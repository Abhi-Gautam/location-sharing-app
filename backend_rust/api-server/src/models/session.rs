use chrono::{DateTime, Utc};
use shared::{
    AppError, AppResult, Constants, Session, SessionDetailsResponse, 
    calculate_expiration_time, is_session_expired
};
use sqlx::{PgPool, Row};
use tracing::debug;
use uuid::Uuid;

/// Repository for session database operations
pub struct SessionRepository {
    pool: PgPool,
}

impl SessionRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// Create a new session
    pub async fn create_session(
        &self,
        name: Option<String>,
        expires_in_minutes: i64,
        creator_id: Uuid,
    ) -> AppResult<Session> {
        let expires_at = calculate_expiration_time(expires_in_minutes);
        
        let session = sqlx::query_as::<_, Session>(
            r#"
            INSERT INTO sessions (name, expires_at, creator_id)
            VALUES ($1, $2, $3)
            RETURNING id, name, created_at, expires_at, creator_id, is_active, last_activity
            "#,
        )
        .bind(name)
        .bind(expires_at)
        .bind(creator_id)
        .fetch_one(&self.pool)
        .await?;

        debug!("Created session: {}", session.id);
        Ok(session)
    }

    /// Get session by ID
    pub async fn get_session(&self, session_id: Uuid) -> AppResult<Session> {
        let session = sqlx::query_as::<_, Session>(
            "SELECT id, name, created_at, expires_at, creator_id, is_active, last_activity FROM sessions WHERE id = $1",
        )
        .bind(session_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(AppError::SessionNotFound)?;

        // Check if session is expired
        if is_session_expired(session.expires_at) {
            return Err(AppError::SessionExpired);
        }

        // Check if session is inactive
        if !session.is_active {
            return Err(AppError::SessionInactive);
        }

        Ok(session)
    }

    /// Get session details with participant count
    pub async fn get_session_details(&self, session_id: Uuid) -> AppResult<SessionDetailsResponse> {
        let row = sqlx::query(
            r#"
            SELECT 
                s.id, s.name, s.created_at, s.expires_at, s.is_active,
                get_active_participant_count(s.id) as participant_count
            FROM sessions s 
            WHERE s.id = $1
            "#,
        )
        .bind(session_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(AppError::SessionNotFound)?;

        let is_active: bool = row.get("is_active");
        let expires_at: DateTime<Utc> = row.get("expires_at");

        // Check if session is expired
        if is_session_expired(expires_at) {
            return Err(AppError::SessionExpired);
        }

        // Check if session is inactive
        if !is_active {
            return Err(AppError::SessionInactive);
        }

        Ok(SessionDetailsResponse {
            id: row.get("id"),
            name: row.get("name"),
            created_at: row.get("created_at"),
            expires_at,
            participant_count: row.get("participant_count"),
            is_active,
        })
    }

    /// End a session (mark as inactive)
    pub async fn end_session(&self, session_id: Uuid, requester_id: Uuid) -> AppResult<()> {
        // Check if the requester is the session creator
        let session = self.get_session(session_id).await?;
        if session.creator_id != requester_id {
            return Err(AppError::UnauthorizedSessionOperation);
        }

        // Mark session as inactive
        let rows_affected = sqlx::query(
            "UPDATE sessions SET is_active = false WHERE id = $1 AND is_active = true",
        )
        .bind(session_id)
        .execute(&self.pool)
        .await?
        .rows_affected();

        if rows_affected == 0 {
            return Err(AppError::SessionNotFound);
        }

        // Mark all participants in the session as inactive
        sqlx::query(
            "UPDATE participants SET is_active = false WHERE session_id = $1",
        )
        .bind(session_id)
        .execute(&self.pool)
        .await?;

        debug!("Ended session: {}", session_id);
        Ok(())
    }

    /// Update session activity timestamp
    pub async fn update_activity(&self, session_id: Uuid) -> AppResult<()> {
        sqlx::query(
            "UPDATE sessions SET last_activity = NOW() WHERE id = $1",
        )
        .bind(session_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// Check if session can accept more participants
    pub async fn can_accept_participants(&self, session_id: Uuid) -> AppResult<bool> {
        let count: i64 = sqlx::query_scalar(
            "SELECT get_active_participant_count($1)",
        )
        .bind(session_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(count < Constants::MAX_PARTICIPANTS_PER_SESSION as i64)
    }

    /// Get all active sessions (for admin/monitoring purposes)
    pub async fn get_active_sessions(&self) -> AppResult<Vec<Session>> {
        let sessions = sqlx::query_as::<_, Session>(
            r#"
            SELECT id, name, created_at, expires_at, creator_id, is_active, last_activity 
            FROM sessions 
            WHERE is_active = true AND expires_at > NOW()
            ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(sessions)
    }

    /// Check if a user is the creator of a session
    pub async fn is_session_creator(&self, session_id: Uuid, user_id: Uuid) -> AppResult<bool> {
        let is_creator: bool = sqlx::query_scalar(
            "SELECT is_session_creator($1, $2)",
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(is_creator)
    }

    /// Get sessions that should be auto-expired due to inactivity
    pub async fn get_sessions_to_auto_expire(&self) -> AppResult<Vec<Uuid>> {
        let session_ids = sqlx::query_scalar::<_, Uuid>(
            r#"
            SELECT id FROM sessions 
            WHERE is_active = true 
            AND last_activity < NOW() - INTERVAL '1 hour'
            AND NOT EXISTS (
                SELECT 1 FROM participants 
                WHERE participants.session_id = sessions.id 
                AND participants.is_active = true 
                AND participants.last_seen > NOW() - INTERVAL '1 hour'
            )
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(session_ids)
    }
}