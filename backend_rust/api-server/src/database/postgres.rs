use shared::{AppConfig, AppError, AppResult};
use sqlx::{PgPool, Row};
use tracing::info;

/// Create a PostgreSQL connection pool
pub async fn create_pool(config: &AppConfig) -> AppResult<PgPool> {
    info!("Connecting to PostgreSQL database...");
    
    let pool = config
        .database_pool_options()
        .connect_with(config.database_options())
        .await?;

    // Test the connection
    let row: (i64,) = sqlx::query_as("SELECT 1")
        .fetch_one(&pool)
        .await?;
    
    if row.0 != 1 {
        return Err(AppError::Database(sqlx::Error::RowNotFound));
    }

    info!("Successfully connected to PostgreSQL database");
    Ok(pool)
}

/// Health check for database connection
pub async fn health_check(pool: &PgPool) -> AppResult<()> {
    let _: (i64,) = sqlx::query_as("SELECT 1")
        .fetch_one(pool)
        .await?;
    Ok(())
}

/// Clean up expired and inactive sessions
pub async fn cleanup_sessions(pool: &PgPool) -> AppResult<(i32, i32)> {
    let mut tx = pool.begin().await?;
    
    // Clean up expired sessions
    let expired_result = sqlx::query("SELECT cleanup_expired_sessions()")
        .fetch_one(&mut *tx)
        .await?;
    let expired_count: i32 = expired_result.get(0);
    
    // Clean up inactive sessions
    let inactive_result = sqlx::query("SELECT cleanup_inactive_sessions()")
        .fetch_one(&mut *tx)
        .await?;
    let inactive_count: i32 = inactive_result.get(0);
    
    tx.commit().await?;
    
    if expired_count > 0 || inactive_count > 0 {
        info!("Cleaned up {} expired and {} inactive sessions", expired_count, inactive_count);
    }
    
    Ok((expired_count, inactive_count))
}

/// Get database statistics
pub async fn get_stats(pool: &PgPool) -> AppResult<DatabaseStats> {
    let stats_row = sqlx::query(
        r#"
        SELECT 
            (SELECT COUNT(*) FROM sessions WHERE is_active = true) as active_sessions,
            (SELECT COUNT(*) FROM sessions) as total_sessions,
            (SELECT COUNT(*) FROM participants WHERE is_active = true) as active_participants,
            (SELECT COUNT(*) FROM participants) as total_participants
        "#
    )
    .fetch_one(pool)
    .await?;
    
    Ok(DatabaseStats {
        active_sessions: stats_row.get("active_sessions"),
        total_sessions: stats_row.get("total_sessions"),
        active_participants: stats_row.get("active_participants"),
        total_participants: stats_row.get("total_participants"),
    })
}

#[derive(Debug)]
pub struct DatabaseStats {
    pub active_sessions: i64,
    pub total_sessions: i64,
    pub active_participants: i64,
    pub total_participants: i64,
}