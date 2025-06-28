use axum::{
    extract::{Path, State},
    Json,
};
use chrono::{Duration, Utc};
use jsonwebtoken::{encode, EncodingKey, Header};
use shared::{
    AppError, Constants, CreateSessionRequest, CreateSessionResponse,
    JoinSessionRequest, JoinSessionResponse, JwtClaims, SessionDetailsResponse, SuccessResponse,
    generate_join_link, generate_user_id, generate_websocket_url, sanitize_session_name,
    generate_session_name,
};
use crate::error::ApiError;
use tracing::{debug, info};
use uuid::Uuid;

use crate::{models::SessionRepository, AppState};

/// Create a new session
pub async fn create_session(
    State(state): State<AppState>,
    Json(request): Json<CreateSessionRequest>,
) -> Result<Json<CreateSessionResponse>, ApiError> {
    debug!("Creating session with request: {:?}", request);

    // Validate request
    request.validate().map_err(|msg| ApiError(AppError::validation("request", &msg)))?;

    let session_repo = SessionRepository::new(state.db.clone());
    
    // Generate creator ID for anonymous session
    let creator_id = Uuid::new_v4();
    
    // Sanitize session name or generate one if not provided
    let session_name = match request.name {
        Some(name) if !name.trim().is_empty() => Some(sanitize_session_name(&name)),
        _ => Some(generate_session_name()),
    };

    // Create the session
    let session = session_repo
        .create_session(session_name.clone(), request.expires_in_minutes, creator_id)
        .await.map_err(ApiError)?;

    // Generate join link
    let join_link = generate_join_link(session.id, &state.config.app.base_url);

    info!("Created session {} with name: {:?}", session.id, session_name);

    let response = CreateSessionResponse {
        session_id: session.id,
        join_link,
        expires_at: session.expires_at,
        name: session_name,
    };

    Ok(Json(response))
}

/// Get session details
pub async fn get_session(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<Json<SessionDetailsResponse>, ApiError> {
    debug!("Getting session details for: {}", session_id);

    let session_repo = SessionRepository::new(state.db.clone());
    let session_details = session_repo.get_session_details(session_id).await.map_err(ApiError)?;

    debug!("Retrieved session details: {:?}", session_details);
    Ok(Json(session_details))
}

/// Join a session
pub async fn join_session(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    Json(request): Json<JoinSessionRequest>,
) -> Result<Json<JoinSessionResponse>, ApiError> {
    debug!("Joining session {} with request: {:?}", session_id, request);

    // Validate request
    request.validate().map_err(|msg| ApiError(AppError::validation("request", &msg)))?;

    let session_repo = SessionRepository::new(state.db.clone());
    
    // Verify session exists and is active
    let _session = session_repo.get_session(session_id).await.map_err(ApiError)?;

    // Check if session can accept more participants
    if !session_repo.can_accept_participants(session_id).await.map_err(ApiError)? {
        return Err(ApiError(AppError::SessionCapacityExceeded {
            max: Constants::MAX_PARTICIPANTS_PER_SESSION,
        }));
    }

    // Generate user ID
    let user_id = generate_user_id();

    // Create participant
    let participant_repo = crate::models::ParticipantRepository::new(state.db.clone());
    let _participant = participant_repo
        .create_participant(
            session_id,
            user_id.clone(),
            request.display_name,
            request.avatar_color,
        )
        .await.map_err(ApiError)?;

    // Generate JWT token for WebSocket authentication
    let claims = JwtClaims {
        sub: user_id.clone(),
        session_id,
        exp: (Utc::now() + Duration::hours(Constants::WS_TOKEN_DURATION_HOURS)).timestamp(),
        iat: Utc::now().timestamp(),
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.config.jwt.secret.as_ref()),
    ).map_err(|e| ApiError(AppError::from(e)))?;

    // Generate WebSocket URL
    let websocket_url = generate_websocket_url(&state.config.app.base_ws_url);

    info!("User {} joined session {}", user_id, session_id);

    let response = JoinSessionResponse {
        user_id: Uuid::parse_str(&user_id).map_err(|e| ApiError(AppError::from(e)))?,
        websocket_token: token,
        websocket_url,
    };

    Ok(Json(response))
}

/// End a session (creator only)
pub async fn end_session(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
    // TODO: Add authentication to get the requester ID
    // For now, we'll use a placeholder approach
) -> Result<Json<SuccessResponse>, ApiError> {
    debug!("Ending session: {}", session_id);

    let session_repo = SessionRepository::new(state.db.clone());
    
    // Get session to verify it exists
    let session = session_repo.get_session(session_id).await.map_err(ApiError)?;
    
    // For MVP without authentication, allow ending by creator_id
    // In production, this would need proper authentication
    session_repo.end_session(session_id, session.creator_id).await.map_err(ApiError)?;

    info!("Ended session: {}", session_id);

    Ok(Json(SuccessResponse { success: true }))
}