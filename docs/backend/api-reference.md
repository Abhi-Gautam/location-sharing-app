# API Reference

Complete REST API and WebSocket API documentation for the Location Sharing backend.

## 🌐 Base URL

```
Development: http://localhost:4000
Production:  https://your-domain.com
```

## 🔗 REST API Endpoints

### Health Checks

#### `GET /health`
Basic health status check.

**Response (200)**:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### `GET /health/detailed`
Detailed health check including dependencies.

**Response (200)**:
```json
{
  "status": "healthy",
  "checks": {
    "database": "healthy",
    "application": "healthy"
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

### Sessions

#### `POST /api/sessions`
Create a new location sharing session.

**Request Body**:
```json
{
  "name": "Weekend Trip",              // optional
  "expires_in_minutes": 1440          // optional, default 1440 (24h)
}
```

**Response (201)**:
```json
{
  "session_id": "uuid",
  "join_link": "http://localhost:4000/join/uuid",
  "expires_at": "2025-01-16T10:30:00Z",
  "name": "Weekend Trip"
}
```

**Errors**:
- `422` - Invalid request data
- `500` - Internal server error

#### `GET /api/sessions/{session_id}`
Get session details and metadata.

**Response (200)**:
```json
{
  "id": "uuid",
  "name": "Weekend Trip",
  "created_at": "2025-01-15T10:30:00Z",
  "expires_at": "2025-01-16T10:30:00Z",
  "participant_count": 5,
  "is_active": true
}
```

**Errors**:
- `404` - Session not found or expired
- `500` - Internal server error

#### `DELETE /api/sessions/{session_id}`
End a session (creator only).

**Response (200)**:
```json
{
  "message": "Session ended successfully"
}
```

**Errors**:
- `404` - Session not found
- `403` - Not session creator
- `500` - Internal server error

### Participants

#### `POST /api/sessions/{session_id}/join`
Join a session as a participant.

**Request Body**:
```json
{
  "display_name": "John Doe",
  "avatar_color": "#FF5733"            // optional, random if not provided
}
```

**Response (201)**:
```json
{
  "user_id": "uuid",
  "websocket_token": "jwt-token-here",
  "websocket_url": "ws://localhost:4000/socket/websocket"
}
```

**Errors**:
- `404` - Session not found or expired
- `422` - Invalid request data
- `500` - Internal server error

#### `GET /api/sessions/{session_id}/participants`
List all participants in a session.

**Response (200)**:
```json
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

**Errors**:
- `404` - Session not found
- `500` - Internal server error

#### `DELETE /api/sessions/{session_id}/participants/{user_id}`
Leave a session.

**Response (200)**:
```json
{
  "message": "Left session successfully"
}
```

**Errors**:
- `404` - Session or participant not found
- `500` - Internal server error

## 🔌 WebSocket API

### Connection

#### Connect to WebSocket
```
ws://localhost:4000/socket/websocket?token={jwt_token}&session_id={session_id}&user_id={user_id}
```

**Authentication**: JWT token obtained from `/api/sessions/{id}/join`

### Phoenix Channels

#### Join Location Channel
```javascript
const channel = socket.channel("location:session_id", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })
```

### Message Types

#### Client → Server Messages

**Location Update**:
```json
{
  "topic": "location:session_id",
  "event": "location_update",
  "payload": {
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": 1234567890
  },
  "ref": "1"
}
```

**Heartbeat**:
```json
{
  "topic": "phoenix",
  "event": "heartbeat",
  "payload": {},
  "ref": "2"
}
```

#### Server → Client Messages

**Channel Join Reply**:
```json
{
  "topic": "location:session_id",
  "event": "phx_reply",
  "payload": {
    "status": "ok",
    "response": {}
  },
  "ref": "1"
}
```

**Location Update Broadcast**:
```json
{
  "topic": "location:session_id",
  "event": "location_update",
  "payload": {
    "user_id": "uuid",
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": 1234567890
  },
  "ref": null
}
```

**Participant Joined**:
```json
{
  "topic": "location:session_id",
  "event": "participant_joined",
  "payload": {
    "user_id": "uuid",
    "display_name": "John Doe",
    "avatar_color": "#FF5733"
  },
  "ref": null
}
```

**Participant Left**:
```json
{
  "topic": "location:session_id",
  "event": "participant_left",
  "payload": {
    "user_id": "uuid"
  },
  "ref": null
}
```

**Initial Participants** (sent after joining):
```json
{
  "topic": "location:session_id",
  "event": "initial_participants",
  "payload": {
    "participants": [
      {
        "user_id": "uuid",
        "display_name": "Jane Doe",
        "avatar_color": "#33FF57"
      }
    ]
  },
  "ref": null
}
```

**Session Ended**:
```json
{
  "topic": "location:session_id",
  "event": "session_ended",
  "payload": {
    "reason": "expired"
  },
  "ref": null
}
```

## 📋 Data Models

### Session
```json
{
  "id": "uuid",
  "name": "string|null",
  "created_at": "datetime",
  "expires_at": "datetime", 
  "creator_id": "string|null",
  "is_active": "boolean",
  "participant_count": "integer"
}
```

### Participant
```json
{
  "user_id": "string",
  "display_name": "string",
  "avatar_color": "string",
  "joined_at": "datetime",
  "last_seen": "datetime",
  "is_active": "boolean"
}
```

### Location Update
```json
{
  "user_id": "string",
  "lat": "float",
  "lng": "float", 
  "accuracy": "float",
  "timestamp": "integer|string"
}
```

## 🔒 Authentication

### JWT Token Structure
```json
{
  "aud": "location_sharing",
  "display_name": "John Doe",
  "exp": 1756392405,
  "iat": 1753973205,
  "iss": "location_sharing",
  "jti": "token-id",
  "nbf": 1753973204,
  "session_id": "session-uuid",
  "sub": "participant-uuid", 
  "typ": "access",
  "user_id": "user-string"
}
```

### Token Usage
- **WebSocket Connection**: Pass as query parameter `?token=jwt_token`
- **Expiration**: 30 days from issue (configurable)
- **Scope**: Limited to specific session

## ⚠️ Rate Limits

### REST API
- **Session Creation**: 10 requests/minute per IP
- **Join Session**: 20 requests/minute per IP
- **General API**: 100 requests/minute per IP

### WebSocket
- **Location Updates**: 1 per 2 seconds (recommended)
- **Heartbeat**: 1 per 30 seconds
- **Connection**: 5 concurrent per IP

## 🚨 Error Codes

### HTTP Status Codes
| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid request format |
| 404 | Not Found | Resource not found |
| 422 | Unprocessable Entity | Invalid request data |
| 500 | Internal Server Error | Server error |

### WebSocket Close Codes
| Code | Meaning | Description |
|------|---------|-------------|
| 1000 | Normal Closure | Clean disconnection |
| 1002 | Protocol Error | Invalid message format |
| 1011 | Server Error | Internal server error |
| 4000 | Authentication Failed | Invalid or expired token |
| 4001 | Session Not Found | Session expired or invalid |

### Application Error Codes
| Code | Meaning | Description |
|------|---------|-------------|
| SESSION_NOT_FOUND | Session not found | Session doesn't exist or expired |
| SESSION_EXPIRED | Session expired | Session past expiration time |
| INVALID_SESSION | Invalid session | Session not active |
| PARTICIPANT_NOT_FOUND | Participant not found | User not in session |
| INVALID_LOCATION_DATA | Invalid location | Location data validation failed |
| UNAUTHORIZED | Unauthorized | Authentication required |

## 📝 Examples

### Create Session and Join Flow

#### 1. Create Session
```bash
curl -X POST http://localhost:4000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Session"}'
```

#### 2. Join Session
```bash
curl -X POST http://localhost:4000/api/sessions/{session_id}/join \
  -H "Content-Type: application/json" \
  -d '{"display_name": "Test User"}'
```

#### 3. Connect WebSocket
```javascript
const socket = new Phoenix.Socket("ws://localhost:4000/socket/websocket", {
  params: {token: jwt_token, session_id: session_id, user_id: user_id}
})

socket.connect()

const channel = socket.channel("location:session_id", {})
channel.join()
```

#### 4. Send Location Update
```javascript
channel.push("location_update", {
  lat: 37.7749,
  lng: -122.4194,
  accuracy: 5.0,
  timestamp: Date.now()
})
```

### Testing with curl

#### Health Check
```bash
curl http://localhost:4000/health
```

#### Create and Test Session
```bash
# Create session
SESSION_RESPONSE=$(curl -s -X POST http://localhost:4000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"name": "API Test Session"}')

SESSION_ID=$(echo $SESSION_RESPONSE | jq -r '.session_id')

# Join session
JOIN_RESPONSE=$(curl -s -X POST http://localhost:4000/api/sessions/$SESSION_ID/join \
  -H "Content-Type: application/json" \
  -d '{"display_name": "API Test User"}')

echo "Session ID: $SESSION_ID"
echo "Join Response: $JOIN_RESPONSE"
```

---

**Note**: All timestamps are in ISO 8601 format (UTC). Location coordinates use decimal degrees (WGS84). WebSocket connections require proper Phoenix Channel protocol handling.