use shared::{
    AppResult, Location, LocationBroadcastData, LocationUpdateData, 
    ParticipantJoinedData, ParticipantLeftData, WebSocketMessage, ErrorData
};
use serde_json;
use tokio::sync::mpsc::UnboundedSender;
use tokio_tungstenite::tungstenite::Message;
use tracing::{debug, error, warn};
use uuid::Uuid;

use crate::ConnectionManager;

/// Connection information for a WebSocket client
#[derive(Debug, Clone)]
pub struct ConnectionInfo {
    pub user_id: String,
    pub session_id: Uuid,
    pub sender: UnboundedSender<Message>,
}

/// Handle incoming WebSocket message from client
pub async fn handle_client_message(
    message: &str,
    user_id: &str,
    session_id: Uuid,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    debug!("Received message from user {}: {}", user_id, message);

    // Parse the WebSocket message
    let ws_message: WebSocketMessage = match serde_json::from_str(message) {
        Ok(msg) => msg,
        Err(e) => {
            error!("Failed to parse WebSocket message: {}", e);
            send_error_to_client(user_id, "INVALID_MESSAGE_FORMAT", "Invalid message format", connection_manager).await?;
            return Ok(());
        }
    };

    // Handle different message types
    match ws_message {
        WebSocketMessage::LocationUpdate(data) => {
            handle_location_update(user_id, session_id, data, connection_manager).await?;
        }
        WebSocketMessage::Ping => {
            handle_ping(user_id, connection_manager).await?;
        }
        _ => {
            warn!("Received unexpected message type from client: {:?}", ws_message);
            send_error_to_client(user_id, "INVALID_MESSAGE_TYPE", "Invalid message type", connection_manager).await?;
        }
    }

    Ok(())
}

/// Handle location update from client
async fn handle_location_update(
    user_id: &str,
    session_id: Uuid,
    data: LocationUpdateData,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    debug!("Handling location update for user {} in session {}", user_id, session_id);

    // Validate location data
    if let Err(msg) = data.validate() {
        send_error_to_client(user_id, "INVALID_LOCATION_DATA", &msg, connection_manager).await?;
        return Ok(());
    }

    // Create location object
    let location = Location {
        lat: data.lat,
        lng: data.lng,
        accuracy: data.accuracy,
        timestamp: data.timestamp,
    };

    // Store location in Redis
    if let Err(e) = connection_manager.redis.store_location(&session_id, user_id, &location).await {
        error!("Failed to store location in Redis: {}", e);
        send_error_to_client(user_id, "LOCATION_STORE_FAILED", "Failed to store location", connection_manager).await?;
        return Ok(());
    }

    // Update session activity
    if let Err(e) = connection_manager.redis.update_session_activity(&session_id).await {
        error!("Failed to update session activity: {}", e);
    }

    // Broadcast location update to other participants
    let broadcast_data = LocationBroadcastData {
        user_id: user_id.to_string(),
        lat: data.lat,
        lng: data.lng,
        accuracy: data.accuracy,
        timestamp: data.timestamp,
    };

    let broadcast_message = WebSocketMessage::LocationBroadcast(broadcast_data);
    let broadcast_json = serde_json::to_string(&broadcast_message)?;

    // Broadcast to all other participants in the session
    connection_manager.broadcast_to_session(session_id, broadcast_json, Some(user_id)).await;

    // Also publish to Redis for other WebSocket server instances
    if let Err(e) = connection_manager.redis.publish_to_session(&session_id, &serde_json::to_string(&broadcast_message)?).await {
        error!("Failed to publish to Redis: {}", e);
    }

    debug!("Location update processed for user {}", user_id);
    Ok(())
}

/// Handle ping message from client
async fn handle_ping(
    user_id: &str,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    debug!("Handling ping from user {}", user_id);

    // Send pong response
    let pong_message = WebSocketMessage::Pong;
    let pong_json = serde_json::to_string(&pong_message)?;

    if let Some(connection_info) = connection_manager.get_connection(user_id).await {
        if let Err(e) = connection_info.sender.send(Message::Text(pong_json)) {
            error!("Failed to send pong to user {}: {}", user_id, e);
        }
    }

    Ok(())
}

/// Send error message to a specific client
async fn send_error_to_client(
    user_id: &str,
    code: &str,
    message: &str,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    let error_data = ErrorData {
        code: code.to_string(),
        message: message.to_string(),
    };

    let error_message = WebSocketMessage::Error(error_data);
    let error_json = serde_json::to_string(&error_message)?;

    if let Some(connection_info) = connection_manager.get_connection(user_id).await {
        if let Err(e) = connection_info.sender.send(Message::Text(error_json)) {
            error!("Failed to send error message to user {}: {}", user_id, e);
        }
    }

    Ok(())
}

/// Notify session participants when a user joins
pub async fn notify_participant_joined(
    session_id: Uuid,
    user_id: &str,
    display_name: &str,
    avatar_color: &str,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    let joined_data = ParticipantJoinedData {
        user_id: user_id.to_string(),
        display_name: display_name.to_string(),
        avatar_color: avatar_color.to_string(),
    };

    let message = WebSocketMessage::ParticipantJoined(joined_data);
    let message_json = serde_json::to_string(&message)?;

    // Broadcast to all participants in the session
    connection_manager.broadcast_to_session(session_id, message_json, Some(user_id)).await;

    // Also publish to Redis for other WebSocket server instances
    if let Err(e) = connection_manager.redis.publish_to_session(&session_id, &serde_json::to_string(&message)?).await {
        error!("Failed to publish participant joined to Redis: {}", e);
    }

    debug!("Notified session {} about participant {} joining", session_id, user_id);
    Ok(())
}

/// Notify session participants when a user leaves
pub async fn notify_participant_left(
    session_id: Uuid,
    user_id: &str,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    let left_data = ParticipantLeftData {
        user_id: user_id.to_string(),
    };

    let message = WebSocketMessage::ParticipantLeft(left_data);
    let message_json = serde_json::to_string(&message)?;

    // Broadcast to all participants in the session
    connection_manager.broadcast_to_session(session_id, message_json, Some(user_id)).await;

    // Also publish to Redis for other WebSocket server instances
    if let Err(e) = connection_manager.redis.publish_to_session(&session_id, &serde_json::to_string(&message)?).await {
        error!("Failed to publish participant left to Redis: {}", e);
    }

    debug!("Notified session {} about participant {} leaving", session_id, user_id);
    Ok(())
}

/// Notify session participants when session ends
pub async fn notify_session_ended(
    session_id: Uuid,
    reason: &str,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    let ended_data = shared::SessionEndedData {
        reason: reason.to_string(),
    };

    let message = WebSocketMessage::SessionEnded(ended_data);
    let message_json = serde_json::to_string(&message)?;

    // Broadcast to all participants in the session
    connection_manager.broadcast_to_session(session_id, message_json, None).await;

    // Also publish to Redis for other WebSocket server instances
    if let Err(e) = connection_manager.redis.publish_to_session(&session_id, &serde_json::to_string(&message)?).await {
        error!("Failed to publish session ended to Redis: {}", e);
    }

    debug!("Notified session {} about session ending: {}", session_id, reason);
    Ok(())
}

/// Send current locations to a newly joined participant
pub async fn send_current_locations(
    session_id: Uuid,
    user_id: &str,
    connection_manager: &ConnectionManager,
) -> AppResult<()> {
    debug!("Sending current locations to user {} in session {}", user_id, session_id);

    // Get all current locations for the session
    let locations = connection_manager.redis.get_session_locations(&session_id).await?;

    if let Some(connection_info) = connection_manager.get_connection(user_id).await {
        for (location_user_id, location) in &locations {
            // Don't send user's own location back to them
            if location_user_id == user_id {
                continue;
            }

            let broadcast_data = LocationBroadcastData {
                user_id: location_user_id.to_string(),
                lat: location.lat,
                lng: location.lng,
                accuracy: location.accuracy,
                timestamp: location.timestamp,
            };

            let message = WebSocketMessage::LocationBroadcast(broadcast_data);
            let message_json = serde_json::to_string(&message)?;

            if let Err(e) = connection_info.sender.send(Message::Text(message_json)) {
                error!("Failed to send location to user {}: {}", user_id, e);
            }
        }
    }

    debug!("Sent {} current locations to user {}", locations.len(), user_id);
    Ok(())
}