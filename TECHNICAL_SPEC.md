# Technical Specification - Real-Time Location Sharing App

## Overview
Real-time location sharing application with dual backend strategy (Rust + Elixir) and Flutter mobile client.

## Architecture Decisions

### Port Configuration
- **Rust API Server**: 8080
- **Rust WebSocket Server**: 8081  
- **Elixir Phoenix**: 4000
- **PostgreSQL**: 5432
- **Redis**: 6379

### Session Behavior
- **Max Duration**: 24 hours
- **Auto-expire**: 1 hour of inactivity (no participants)
- **Creator Permissions**: Can end session manually
- **Max Participants**: 50 per session

### Location Privacy
- **Storage**: Redis only (no PostgreSQL history)
- **Retention**: 30 seconds TTL in Redis
- **Updates**: Every 2 seconds from client

### Authentication
- **Anonymous Only**: No account creation for MVP
- **Session Security**: Link-based access only
- **WebSocket Auth**: JWT tokens for connection validation

## Database Schemas

### PostgreSQL
```sql
-- Sessions
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    creator_id UUID,
    is_active BOOLEAN DEFAULT true,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Participants  
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    avatar_color VARCHAR(7) DEFAULT '#FF5733',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Indexes
CREATE INDEX idx_sessions_active ON sessions(is_active, expires_at);
CREATE INDEX idx_sessions_activity ON sessions(last_activity);
CREATE INDEX idx_participants_session ON participants(session_id, is_active);
```

### Redis Data Structures
```
# Real-time locations (30s TTL)
locations:{session_id}:{user_id} = {
  "lat": 37.7749,
  "lng": -122.4194,
  "timestamp": "2025-01-15T10:30:00Z",
  "accuracy": 5.0
}

# Active session participants (set)
session_participants:{session_id} = {user_id1, user_id2, ...}

# WebSocket connection mapping
connections:{user_id} = {connection_id}

# Session activity tracking
session_activity:{session_id} = timestamp

# Pub/Sub channels
channel:session:{session_id} = location_updates, join/leave events
```

## REST API Specification

### Base URL
- Rust: `http://localhost:8080/api`
- Elixir: `http://localhost:4000/api`

### Endpoints

#### POST /sessions
Create new session
```json
Request:
{
  "name": "Weekend Trip", // optional
  "expires_in_minutes": 1440 // optional, default 1440 (24h)
}

Response: 201
{
  "session_id": "uuid",
  "join_link": "https://app.com/join/uuid",
  "expires_at": "2025-01-16T10:30:00Z",
  "name": "Weekend Trip"
}
```

#### GET /sessions/{session_id}
Get session details
```json
Response: 200
{
  "id": "uuid",
  "name": "Weekend Trip",
  "created_at": "2025-01-15T10:30:00Z",
  "expires_at": "2025-01-16T10:30:00Z",
  "participant_count": 5,
  "is_active": true
}
```

#### POST /sessions/{session_id}/join
Join session
```json
Request:
{
  "display_name": "John Doe",
  "avatar_color": "#FF5733" // optional
}

Response: 201
{
  "user_id": "uuid",
  "websocket_token": "jwt-token",
  "websocket_url": "ws://localhost:8081/ws"
}
```

#### DELETE /sessions/{session_id}/participants/{user_id}
Leave session
```json
Response: 200
{
  "success": true
}
```

#### GET /sessions/{session_id}/participants
List participants
```json
Response: 200
{
  "participants": [
    {
      "user_id": "uuid",
      "display_name": "John Doe", 
      "avatar_color": "#FF5733",
      "last_seen": "2025-01-15T10:30:00Z",
      "is_active": true
    }
  ]
}
```

#### DELETE /sessions/{session_id}
End session (creator only)
```json
Response: 200
{
  "success": true
}
```

## WebSocket Specification

### Connection
- **Rust**: `ws://localhost:8081/ws?token={jwt_token}`
- **Elixir**: `ws://localhost:4000/socket/websocket`

### Message Format
All messages follow this structure:
```json
{
  "type": "message_type",
  "data": { /* message-specific data */ }
}
```

### Client → Server Messages

#### location_update
```json
{
  "type": "location_update",
  "data": {
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

#### ping
```json
{
  "type": "ping",
  "data": {}
}
```

### Server → Client Messages

#### participant_joined
```json
{
  "type": "participant_joined",
  "data": {
    "user_id": "uuid",
    "display_name": "John Doe",
    "avatar_color": "#FF5733"
  }
}
```

#### participant_left
```json
{
  "type": "participant_left", 
  "data": {
    "user_id": "uuid"
  }
}
```

#### location_update
```json
{
  "type": "location_update",
  "data": {
    "user_id": "uuid",
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

#### session_ended
```json
{
  "type": "session_ended",
  "data": {
    "reason": "expired" // or "ended_by_creator"
  }
}
```

#### pong
```json
{
  "type": "pong",
  "data": {}
}
```

#### error
```json
{
  "type": "error",
  "data": {
    "code": "INVALID_SESSION",
    "message": "Session not found or expired"
  }
}
```

## Technology Stack

### Rust Backend
- **Framework**: Axum 0.7+
- **Runtime**: Tokio
- **Database**: SQLx with PostgreSQL
- **Redis**: redis-rs with tokio support
- **WebSocket**: tokio-tungstenite
- **JSON**: serde + serde_json
- **UUID**: uuid crate
- **JWT**: jsonwebtoken
- **Config**: config crate
- **Logging**: tracing + tracing-subscriber

### Elixir Backend  
- **Framework**: Phoenix 1.7+
- **Database**: Ecto 3.10+ with PostgreSQL
- **Redis**: Redix
- **WebSocket**: Phoenix Channels
- **JSON**: Jason
- **UUID**: Ecto.UUID
- **JWT**: Guardian
- **Config**: Phoenix config system

### Flutter Frontend
- **Version**: Flutter 3.16+
- **State Management**: Riverpod
- **HTTP Client**: Dio
- **WebSocket**: web_socket_channel
- **Maps**: google_maps_flutter
- **Location**: geolocator
- **Permissions**: permission_handler
- **Storage**: shared_preferences
- **UUID**: uuid

## Project Structure

### Rust Backend (`backend_rust/`)
```
backend_rust/
├── Cargo.toml (workspace)
├── docker-compose.yml
├── .env.example
├── api-server/
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs
│       ├── config.rs
│       ├── error.rs
│       ├── models/
│       │   ├── mod.rs
│       │   ├── session.rs
│       │   └── participant.rs
│       ├── handlers/
│       │   ├── mod.rs
│       │   ├── sessions.rs
│       │   └── participants.rs
│       ├── database/
│       │   ├── mod.rs
│       │   └── postgres.rs
│       └── middleware/
│           ├── mod.rs
│           └── cors.rs
├── websocket-server/
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs
│       ├── config.rs
│       ├── error.rs
│       ├── handlers/
│       │   ├── mod.rs
│       │   └── websocket.rs
│       ├── redis/
│       │   ├── mod.rs
│       │   └── client.rs
│       └── auth/
│           ├── mod.rs
│           └── jwt.rs
├── shared/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── types.rs
│       └── utils.rs
└── migrations/
    └── 001_initial.sql
```

### Elixir Backend (`backend_elixir/`)
```
backend_elixir/
├── mix.exs
├── .env.example
├── config/
│   ├── config.exs
│   ├── dev.exs  
│   ├── prod.exs
│   └── test.exs
├── lib/
│   ├── location_sharing/
│   │   ├── application.ex
│   │   ├── repo.ex
│   │   ├── redis.ex
│   │   └── sessions/
│   │       ├── session.ex
│   │       ├── participant.ex
│   │       └── session_server.ex
│   └── location_sharing_web/
│       ├── endpoint.ex
│       ├── router.ex
│       ├── controllers/
│       │   ├── session_controller.ex
│       │   └── participant_controller.ex
│       ├── channels/
│       │   ├── user_socket.ex
│       │   └── location_channel.ex
│       └── views/
│           ├── session_view.ex
│           └── participant_view.ex
├── priv/
│   └── repo/
│       └── migrations/
│           └── 001_create_sessions_and_participants.exs
└── test/
```

### Flutter Frontend (`mobile_app/`)
```
mobile_app/
├── pubspec.yaml
├── .env.example
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── app_config.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── constants.dart
│   │   ├── utils.dart
│   │   └── extensions.dart
│   ├── models/
│   │   ├── session.dart
│   │   ├── participant.dart
│   │   └── location.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── websocket_service.dart
│   │   ├── location_service.dart
│   │   └── storage_service.dart
│   ├── providers/
│   │   ├── session_provider.dart
│   │   ├── location_provider.dart
│   │   └── participants_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── create_session_screen.dart
│   │   ├── join_session_screen.dart
│   │   └── map_screen.dart
│   └── widgets/
│       ├── map_widget.dart
│       ├── participant_avatar.dart
│       └── session_controls.dart
├── android/
├── ios/
└── test/
```

## Implementation Guidelines

### Code Quality Standards
1. **Error Handling**: Comprehensive error handling with proper error types
2. **Logging**: Structured logging for debugging and monitoring
3. **Testing**: Unit tests for business logic, integration tests for APIs
4. **Documentation**: Inline documentation for complex logic
5. **Security**: Input validation, SQL injection prevention, XSS protection
6. **Performance**: Efficient database queries, connection pooling, caching

### Common Patterns
1. **Repository Pattern**: Database access abstraction
2. **Service Layer**: Business logic separation
3. **DTO/Model Separation**: API models vs domain models
4. **Configuration Management**: Environment-based configuration
5. **Graceful Shutdown**: Proper cleanup on application termination

### Development Workflow
1. **Database First**: Set up migrations and schemas
2. **API First**: Implement REST endpoints
3. **WebSocket Integration**: Real-time communication
4. **Frontend Integration**: Mobile app implementation
5. **Testing**: End-to-end testing across all components

## Environment Configuration

### Required Environment Variables
```bash
# Database
DATABASE_URL=postgresql://dev:dev123@localhost:5432/location_sharing
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-super-secret-jwt-key

# Rust specific
RUST_API_PORT=8080
RUST_WS_PORT=8081

# Elixir specific  
PHX_PORT=4000
SECRET_KEY_BASE=phoenix-secret-key-base

# Flutter specific
BACKEND_TYPE=elixir # or 'rust'
API_BASE_URL=http://localhost:4000/api
WS_BASE_URL=ws://localhost:4000/socket/websocket
```

This specification serves as the single source of truth for all implementation agents.