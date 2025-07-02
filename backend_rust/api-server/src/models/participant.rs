use shared::{
    AppError, AppResult, Constants, Participant, ParticipantResponse, 
    generate_avatar_color, sanitize_display_name
};
use sqlx::PgPool;
use tracing::debug;
use uuid::Uuid;

/// Repository for participant database operations
pub struct ParticipantRepository {
    pool: PgPool,
}

impl ParticipantRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// Add a participant to a session
    pub async fn create_participant(
        &self,
        session_id: Uuid,
        user_id: String,
        display_name: String,
        avatar_color: Option<String>,
    ) -> AppResult<Participant> {
        // Sanitize display name
        let display_name = sanitize_display_name(&display_name);
        if display_name.is_empty() {
            return Err(AppError::invalid_participant_data("Display name cannot be empty"));
        }

        // Use provided avatar color or generate one
        let avatar_color = avatar_color.unwrap_or_else(generate_avatar_color);

        // Check if participant already exists in this session
        let existing = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM participants WHERE session_id = $1 AND user_id = $2)",
        )
        .bind(session_id)
        .bind(&user_id)
        .fetch_one(&self.pool)
        .await?;

        if existing {
            return Err(AppError::ParticipantAlreadyExists);
        }

        // Check session capacity
        let participant_count: i64 = sqlx::query_scalar(
            "SELECT get_active_participant_count($1)::bigint",
        )
        .bind(session_id)
        .fetch_one(&self.pool)
        .await?;

        if participant_count >= Constants::MAX_PARTICIPANTS_PER_SESSION as i64 {
            return Err(AppError::SessionCapacityExceeded {
                max: Constants::MAX_PARTICIPANTS_PER_SESSION,
            });
        }

        // Create the participant
        let participant = sqlx::query_as::<_, Participant>(
            r#"
            INSERT INTO participants (session_id, user_id, display_name, avatar_color)
            VALUES ($1, $2, $3, $4)
            RETURNING id, session_id, user_id, display_name, avatar_color, joined_at, last_seen, is_active
            "#,
        )
        .bind(session_id)
        .bind(&user_id)
        .bind(&display_name)
        .bind(&avatar_color)
        .fetch_one(&self.pool)
        .await?;

        debug!("Created participant {} in session {}", user_id, session_id);
        Ok(participant)
    }

    /// Get participant by session and user ID
    pub async fn get_participant(&self, session_id: Uuid, user_id: &str) -> AppResult<Participant> {
        let participant = sqlx::query_as::<_, Participant>(
            r#"
            SELECT id, session_id, user_id, display_name, avatar_color, joined_at, last_seen, is_active
            FROM participants 
            WHERE session_id = $1 AND user_id = $2
            "#,
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(AppError::ParticipantNotFound)?;

        Ok(participant)
    }

    /// List all active participants in a session
    pub async fn list_participants(&self, session_id: Uuid) -> AppResult<Vec<ParticipantResponse>> {
        let participants = sqlx::query_as::<_, ParticipantResponse>(
            r#"
            SELECT user_id, display_name, avatar_color, last_seen, is_active
            FROM participants 
            WHERE session_id = $1 AND is_active = true
            ORDER BY joined_at ASC
            "#,
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(participants)
    }

    /// Remove a participant from a session
    pub async fn remove_participant(&self, session_id: Uuid, user_id: &str) -> AppResult<()> {
        let rows_affected = sqlx::query(
            "UPDATE participants SET is_active = false WHERE session_id = $1 AND user_id = $2",
        )
        .bind(session_id)
        .bind(user_id)
        .execute(&self.pool)
        .await?
        .rows_affected();

        if rows_affected == 0 {
            return Err(AppError::ParticipantNotFound);
        }

        debug!("Removed participant {} from session {}", user_id, session_id);
        Ok(())
    }

    /// Update participant's last seen timestamp
    pub async fn update_last_seen(&self, session_id: Uuid, user_id: &str) -> AppResult<()> {
        sqlx::query(
            "UPDATE participants SET last_seen = NOW() WHERE session_id = $1 AND user_id = $2",
        )
        .bind(session_id)
        .bind(user_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// Get participant count for a session
    pub async fn get_participant_count(&self, session_id: Uuid) -> AppResult<i64> {
        let count = sqlx::query_scalar::<_, i64>(
            "SELECT get_active_participant_count($1)::bigint",
        )
        .bind(session_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(count)
    }

    /// Check if a participant exists in a session
    pub async fn participant_exists(&self, session_id: Uuid, user_id: &str) -> AppResult<bool> {
        let exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM participants WHERE session_id = $1 AND user_id = $2 AND is_active = true)",
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(exists)
    }

    /// Get all participants for a session (including inactive ones)
    pub async fn get_all_participants_for_session(&self, session_id: Uuid) -> AppResult<Vec<Participant>> {
        let participants = sqlx::query_as::<_, Participant>(
            r#"
            SELECT id, session_id, user_id, display_name, avatar_color, joined_at, last_seen, is_active
            FROM participants 
            WHERE session_id = $1
            ORDER BY joined_at ASC
            "#,
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(participants)
    }

    /// Reactivate a participant (if they rejoin)
    pub async fn reactivate_participant(&self, session_id: Uuid, user_id: &str) -> AppResult<Participant> {
        let participant = sqlx::query_as::<_, Participant>(
            r#"
            UPDATE participants 
            SET is_active = true, last_seen = NOW()
            WHERE session_id = $1 AND user_id = $2
            RETURNING id, session_id, user_id, display_name, avatar_color, joined_at, last_seen, is_active
            "#,
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(AppError::ParticipantNotFound)?;

        debug!("Reactivated participant {} in session {}", user_id, session_id);
        Ok(participant)
    }

    /// Clean up inactive participants
    pub async fn cleanup_inactive_participants(&self, inactivity_minutes: i64) -> AppResult<usize> {
        let rows_affected = sqlx::query(
            r#"
            UPDATE participants 
            SET is_active = false 
            WHERE is_active = true 
            AND last_seen < NOW() - INTERVAL '1 minute' * $1
            "#,
        )
        .bind(inactivity_minutes)
        .execute(&self.pool)
        .await?
        .rows_affected();

        if rows_affected > 0 {
            debug!("Cleaned up {} inactive participants", rows_affected);
        }

        Ok(rows_affected as usize)
    }
}