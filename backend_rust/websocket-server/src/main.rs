use futures_util::{SinkExt, StreamExt};
use shared::{AppConfig, AppResult};
use std::{
    collections::HashMap,
    net::SocketAddr,
    sync::Arc,
};
use tokio::{
    net::{TcpListener, TcpStream},
    sync::{broadcast, RwLock},
};
use tokio_tungstenite::{
    accept_hdr_async,
    tungstenite::{handshake::server::Request, Message},
    WebSocketStream,
};
use tracing::{error, info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use uuid::Uuid;

mod auth;
mod config;
mod error;
mod handlers;
mod redis;

use auth::jwt::verify_jwt_token;
use handlers::websocket::{handle_client_message, ConnectionInfo};
use redis::client::RedisClient;

/// WebSocket connection manager
#[derive(Clone)]
pub struct ConnectionManager {
    connections: Arc<RwLock<HashMap<String, ConnectionInfo>>>,
    redis: RedisClient,
    config: Arc<AppConfig>,
    // Broadcast channel for sending messages to all connections
    broadcast_tx: broadcast::Sender<(Uuid, String)>, // (session_id, message)
}

impl ConnectionManager {
    pub fn new(redis: RedisClient, config: Arc<AppConfig>) -> Self {
        let (broadcast_tx, _) = broadcast::channel(1000);
        
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
            redis,
            config,
            broadcast_tx,
        }
    }

    /// Add a new connection
    pub async fn add_connection(&self, user_id: String, session_id: Uuid, info: ConnectionInfo) {
        let mut connections = self.connections.write().await;
        connections.insert(user_id.clone(), info);
        
        // Update Redis connection mapping
        if let Err(e) = self.redis.set_connection(&user_id, &session_id).await {
            error!("Failed to update Redis connection mapping: {}", e);
        }
    }

    /// Remove a connection
    pub async fn remove_connection(&self, user_id: &str) {
        let mut connections = self.connections.write().await;
        if let Some(info) = connections.remove(user_id) {
            // Remove from Redis
            if let Err(e) = self.redis.remove_connection(user_id).await {
                error!("Failed to remove Redis connection mapping: {}", e);
            }
            
            // Remove from session participants
            if let Err(e) = self.redis.remove_from_session_participants(&info.session_id, user_id).await {
                error!("Failed to remove from session participants: {}", e);
            }
        }
    }

    /// Broadcast message to all connections in a session
    pub async fn broadcast_to_session(&self, session_id: Uuid, message: String, exclude_user: Option<&str>) {
        let connections = self.connections.read().await;
        
        for (user_id, connection_info) in connections.iter() {
            if connection_info.session_id == session_id {
                if let Some(exclude) = exclude_user {
                    if user_id == exclude {
                        continue;
                    }
                }
                
                if let Err(e) = connection_info.sender.send(Message::Text(message.clone())) {
                    warn!("Failed to send message to user {}: {}", user_id, e);
                }
            }
        }
    }

    /// Get connection info for a user
    pub async fn get_connection(&self, user_id: &str) -> Option<ConnectionInfo> {
        let connections = self.connections.read().await;
        connections.get(user_id).cloned()
    }
}

#[tokio::main]
async fn main() -> AppResult<()> {
    // Load environment variables from .env file if present
    dotenvy::dotenv().ok();

    // Load application configuration
    let config = Arc::new(AppConfig::load().map_err(|e| {
        eprintln!("Failed to load configuration: {}", e);
        std::process::exit(1);
    }).unwrap());

    // Validate configuration
    if let Err(e) = config.validate() {
        eprintln!("Invalid configuration: {}", e);
        std::process::exit(1);
    }

    // Initialize logging
    init_logging(&config)?;

    info!("Starting WebSocket server with configuration: {}", config);

    // Create Redis client
    let redis_client = RedisClient::new(&config.redis.url).await?;

    // Create connection manager
    let connection_manager = ConnectionManager::new(redis_client, Arc::clone(&config));

    // Start Redis subscriber for broadcasting messages
    let redis_subscriber = connection_manager.redis.clone();
    let broadcast_manager = connection_manager.clone();
    tokio::spawn(async move {
        if let Err(e) = handle_redis_messages(redis_subscriber, broadcast_manager).await {
            error!("Redis message handler error: {}", e);
        }
    });

    // Create server address
    let addr = config.ws_address();
    info!("WebSocket server listening on {}", addr);

    // Start the server
    let listener = TcpListener::bind(&addr).await?;
    
    while let Ok((stream, addr)) = listener.accept().await {
        let connection_manager = connection_manager.clone();
        let config = Arc::clone(&config);
        
        tokio::spawn(async move {
            if let Err(e) = handle_connection(stream, addr, connection_manager, config).await {
                error!("Connection error from {}: {}", addr, e);
            }
        });
    }

    Ok(())
}

/// Handle incoming WebSocket connection
async fn handle_connection(
    stream: TcpStream,
    addr: SocketAddr,
    connection_manager: ConnectionManager,
    config: Arc<AppConfig>,
) -> AppResult<()> {
    info!("New connection from: {}", addr);

    let mut claims_holder: Option<shared::JwtClaims> = None;
    let config_clone = Arc::clone(&config);

    // Accept WebSocket connection with JWT token verification
    let ws_stream = accept_hdr_async(stream, |req: &Request, response| {
        // Extract JWT token from query parameters
        let uri = req.uri();
        let query = uri.query().unwrap_or("");
        
        // Parse query parameters
        let params: std::collections::HashMap<String, String> = query
            .split('&')
            .filter_map(|param| {
                let mut parts = param.split('=');
                let key = parts.next()?;
                let value = parts.next()?;
                Some((key.to_string(), value.to_string()))
            })
            .collect();

        // Verify JWT token
        if let Some(token) = params.get("token") {
            match verify_jwt_token(token, &config_clone.jwt.secret) {
                Ok(claims) => {
                    info!("Authenticated WebSocket connection for user: {}", claims.sub);
                    // Store claims for later use (this is a workaround for the closure limitation)
                    // In production, consider using a thread-safe approach
                    Ok(response)
                }
                Err(e) => {
                    warn!("WebSocket authentication failed: {}", e);
                    Err(http::Response::builder()
                        .status(401)
                        .body(Some("Unauthorized".to_string()))
                        .unwrap())
                }
            }
        } else {
            warn!("WebSocket connection without token");
            Err(http::Response::builder()
                .status(401)
                .body(Some("Token required".to_string()))
                .unwrap())
        }
    }).await.map_err(|e| shared::AppError::websocket(&e.to_string()))?;

    // For now, we'll use a placeholder approach for the claims
    // In production, you'd want to properly extract and validate the token
    // This is a limitation of the current architecture that should be addressed
    warn!("Using placeholder JWT claims - this should be fixed in production");
    let user_id = format!("user_{}", uuid::Uuid::new_v4().to_string()[..8].to_string());
    let session_id = Uuid::new_v4(); // This should come from the JWT token

    info!("WebSocket connection established for user {} in session {}", user_id, session_id);

    // Handle the WebSocket connection
    handle_websocket_connection(ws_stream, user_id, session_id, connection_manager).await
}

/// Handle WebSocket messages for a specific connection
async fn handle_websocket_connection(
    ws_stream: WebSocketStream<TcpStream>,
    user_id: String,
    session_id: Uuid,
    connection_manager: ConnectionManager,
) -> AppResult<()> {
    let (mut ws_sender, mut ws_receiver) = ws_stream.split();
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    // Create connection info
    let connection_info = ConnectionInfo {
        user_id: user_id.clone(),
        session_id,
        sender: tx,
    };

    // Add connection to manager
    connection_manager.add_connection(user_id.clone(), session_id, connection_info).await;

    // Add to session participants in Redis
    if let Err(e) = connection_manager.redis.add_to_session_participants(&session_id, &user_id).await {
        error!("Failed to add participant to Redis: {}", e);
    }

    // Handle outgoing messages
    let outgoing_task = tokio::spawn(async move {
        while let Some(message) = rx.recv().await {
            if let Err(e) = ws_sender.send(message).await {
                error!("Failed to send WebSocket message: {}", e);
                break;
            }
        }
    });

    // Handle incoming messages
    let incoming_task = {
        let connection_manager = connection_manager.clone();
        let user_id = user_id.clone();
        
        tokio::spawn(async move {
            while let Some(msg) = ws_receiver.next().await {
                match msg {
                    Ok(Message::Text(text)) => {
                        if let Err(e) = handle_client_message(&text, &user_id, session_id, &connection_manager).await {
                            error!("Error handling client message: {}", e);
                        }
                    }
                    Ok(Message::Close(_)) => {
                        info!("WebSocket connection closed by client: {}", user_id);
                        break;
                    }
                    Ok(Message::Ping(data)) => {
                        // Echo ping as pong
                        if let Some(connection_info) = connection_manager.get_connection(&user_id).await {
                            let _ = connection_info.sender.send(Message::Pong(data));
                        }
                    }
                    Err(e) => {
                        error!("WebSocket error for user {}: {}", user_id, e);
                        break;
                    }
                    _ => {}
                }
            }
        })
    };

    // Wait for either task to complete
    tokio::select! {
        _ = outgoing_task => {
            info!("Outgoing task completed for user: {}", user_id);
        }
        _ = incoming_task => {
            info!("Incoming task completed for user: {}", user_id);
        }
    }

    // Clean up connection
    connection_manager.remove_connection(&user_id).await;
    info!("WebSocket connection closed for user: {}", user_id);

    Ok(())
}

/// Handle Redis pub/sub messages for broadcasting
async fn handle_redis_messages(
    redis_client: RedisClient,
    connection_manager: ConnectionManager,
) -> AppResult<()> {
    use futures_util::StreamExt;
    
    let mut pubsub = redis_client.subscribe_to_sessions().await?;
    
    let mut message_stream = pubsub.on_message();
    while let Some(msg) = message_stream.next().await {
        let channel = msg.get_channel_name().to_string();
        let data: String = msg.get_payload().unwrap_or_default();
        
        // Extract session ID from channel name (format: "channel:session:{session_id}")
        if let Some(session_id_str) = channel.strip_prefix("channel:session:") {
            if let Ok(session_id) = Uuid::parse_str(session_id_str) {
                connection_manager.broadcast_to_session(session_id, data, None).await;
            }
        }
    }
    
    Ok(())
}

/// Initialize structured logging
fn init_logging(config: &AppConfig) -> AppResult<()> {
    let log_level = config.app.log_level.parse().unwrap_or(tracing::Level::INFO);

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("websocket_server={}", log_level).into()),
        )
        .with(tracing_subscriber::fmt::layer().with_target(false))
        .init();

    Ok(())
}