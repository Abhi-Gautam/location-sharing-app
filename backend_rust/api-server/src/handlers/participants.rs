use axum::{
    extract::{Path, State},
    Json,
};
use shared::{ParticipantsListResponse, SuccessResponse};
use crate::error::ApiError;
use tracing::{debug, info};
use uuid::Uuid;

use crate::{models::ParticipantRepository, AppState};

/// List all participants in a session
pub async fn list_participants(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<Json<ParticipantsListResponse>, ApiError> {
    debug!("Listing participants for session: {}", session_id);

    let participant_repo = ParticipantRepository::new(state.db.clone());
    let participants = participant_repo.list_participants(session_id).await.map_err(ApiError)?;

    debug!("Found {} participants in session {}", participants.len(), session_id);

    let response = ParticipantsListResponse { participants };
    Ok(Json(response))
}

/// Remove a participant from a session
pub async fn leave_session(
    State(state): State<AppState>,
    Path((session_id, user_id)): Path<(Uuid, String)>,
) -> Result<Json<SuccessResponse>, ApiError> {
    debug!("Removing participant {} from session {}", user_id, session_id);

    let participant_repo = ParticipantRepository::new(state.db.clone());
    participant_repo.remove_participant(session_id, &user_id).await.map_err(ApiError)?;

    info!("Participant {} left session {}", user_id, session_id);

    Ok(Json(SuccessResponse { success: true }))
}