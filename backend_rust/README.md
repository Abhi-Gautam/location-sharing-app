# Real-Time Location Sharing - Rust Backend

A high-performance, enterprise-grade Rust backend for real-time location sharing application using a dual-microservice architecture.

## Architecture Overview

The Rust backend consists of three main components:

1. **API Server** (Port 8080): REST API using Axum framework
2. **WebSocket Server** (Port 8081): Real-time communication using tokio-tungstenite
3. **Shared Library**: Common types, error handling, and utilities

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Server    │    │ WebSocket Server │    │  Shared Library │
│     (8080)      │    │      (8081)      │    │                 │
│                 │    │                  │    │  • Types        │
│ • REST API      │    │ • Real-time msgs │    │  • Errors       │
│ • JWT Auth      │    │ • JWT Auth       │    │  • Utils        │
│ • Session Mgmt  │    │ • Connection Mgmt│    │  • Config       │
│ • Participants  │    │ • Location Sync  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌─────────────────┐    ┌──────────────────┐
    │   PostgreSQL    │    │      Redis       │
    │   (Sessions &   │    │  (Locations &    │
    │  Participants)  │    │    Pub/Sub)      │
    └─────────────────┘    └──────────────────┘
```

## Features

### 🚀 High Performance
- **Async/await**: Built on Tokio runtime for maximum concurrency
- **Connection pooling**: Optimized database and Redis connections
- **Memory efficient**: Zero-copy serialization with serde
- **WebSocket scalability**: Handle thousands of concurrent connections

### 🔒 Security & Reliability
- **JWT authentication**: Secure WebSocket connections
- **Input validation**: Comprehensive request validation
- **Error handling**: Structured error types with proper HTTP status codes
- **CORS support**: Configurable cross-origin resource sharing
- **Health checks**: Built-in monitoring endpoints

### 📊 Enterprise Features
- **Structured logging**: JSON-based logging with tracing
- **Configuration management**: Environment-based configuration
- **Database migrations**: Versioned schema management
- **Docker support**: Production-ready containerization
- **Graceful shutdown**: Proper cleanup on termination

### 🌊 Real-time Capabilities
- **WebSocket communication**: Bi-directional real-time messaging
- **Redis pub/sub**: Scalable message broadcasting
- **Location TTL**: Automatic cleanup of stale location data
- **Session management**: Automatic session expiration

## Quick Start

### Prerequisites

- Rust 1.75+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose (optional)

### Development Setup

1. **Clone and navigate to the backend:**
   ```bash
   cd backend_rust
   ```

2. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start infrastructure with Docker:**
   ```bash
   docker-compose up -d postgres redis
   ```

4. **Run database migrations:**
   ```bash
   cargo install sqlx-cli
   sqlx migrate run --database-url postgresql://dev:dev123@localhost:5432/location_sharing
   ```

5. **Start the API server:**
   ```bash
   cargo run --bin api-server
   ```

6. **Start the WebSocket server (in another terminal):**
   ```bash
   cargo run --bin websocket-server
   ```

### Docker Deployment

**Start all services:**
```bash
docker-compose up -d
```

**View logs:**
```bash
docker-compose logs -f api-server websocket-server
```

**Stop services:**
```bash
docker-compose down
```

## API Reference

### Base URL
```
http://localhost:8080/api
```

### Endpoints

#### Create Session
```http
POST /sessions
Content-Type: application/json

{
  "name": "Weekend Trip",
  "expires_in_minutes": 1440
}
```

**Response:**
```json
{
  "session_id": "uuid",
  "join_link": "https://app.com/join/uuid",
  "expires_at": "2025-01-16T10:30:00Z",
  "name": "Weekend Trip"
}
```

#### Get Session Details
```http
GET /sessions/{session_id}
```

#### Join Session
```http
POST /sessions/{session_id}/join
Content-Type: application/json

{
  "display_name": "John Doe",
  "avatar_color": "#FF5733"
}
```

**Response:**
```json
{
  "user_id": "uuid",
  "websocket_token": "jwt-token",
  "websocket_url": "ws://localhost:8081/ws"
}
```

#### List Participants
```http
GET /sessions/{session_id}/participants
```

#### Leave Session
```http
DELETE /sessions/{session_id}/participants/{user_id}
```

#### End Session
```http
DELETE /sessions/{session_id}
```

### WebSocket Connection

**Connection URL:**
```
ws://localhost:8081/ws?token={jwt_token}
```

#### Message Format
All messages follow this structure:
```json
{
  "type": "message_type",
  "data": { /* message-specific data */ }
}
```

#### Client → Server Messages

**Location Update:**
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

**Ping:**
```json
{
  "type": "ping",
  "data": {}
}
```

#### Server → Client Messages

**Participant Joined:**
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

**Location Broadcast:**
```json
{
  "type": "location_broadcast",
  "data": {
    "user_id": "uuid",
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

## Configuration

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://dev:dev123@localhost:5432/location_sharing

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-super-secret-jwt-key-change-in-production

# Server Ports
RUST_API_PORT=8080
RUST_WS_PORT=8081

# Application Settings
APP__APP__ENVIRONMENT=development
APP__APP__LOG_LEVEL=info
APP__APP__MAX_PARTICIPANTS_PER_SESSION=50
APP__APP__LOCATION_TTL_SECONDS=30
```

### Production Configuration

For production deployment, ensure you:

1. **Set a strong JWT secret** (32+ characters)
2. **Configure CORS origins** properly
3. **Use SSL/TLS** for HTTPS and WSS
4. **Set up monitoring** and alerting
5. **Configure log aggregation**

## Database Schema

### Sessions Table
```sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    creator_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Participants Table
```sql
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    avatar_color VARCHAR(7) DEFAULT '#FF5733',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(session_id, user_id)
);
```

## Redis Data Structures

```
# Real-time locations (30s TTL)
locations:{session_id}:{user_id} = {location_json}

# Active session participants
session_participants:{session_id} = {user_id1, user_id2, ...}

# WebSocket connections
connections:{user_id} = {session_id}

# Session activity tracking
session_activity:{session_id} = timestamp

# Pub/Sub channels
channel:session:{session_id} = messages
```

## Testing

### Unit Tests
```bash
cargo test
```

### Integration Tests
```bash
# Set up test database
export TEST_DATABASE_URL=postgresql://test:test@localhost:5432/location_sharing_test

# Run integration tests
cargo test --test integration_tests
```

### Load Testing
```bash
# Example using wrk for API endpoints
wrk -t12 -c400 -d30s http://localhost:8080/health

# WebSocket load testing can be done with custom tools
```

## Monitoring & Observability

### Health Checks
- **API Server**: `GET /health`
- **Database**: Connection pool monitoring
- **Redis**: Connection health checks

### Metrics
The application provides structured logging with the following information:
- Request/response times
- Active connections
- Session statistics
- Error rates

### Logging
Configure log levels via environment:
```bash
APP__APP__LOG_LEVEL=debug  # trace, debug, info, warn, error
```

## Troubleshooting

### Common Issues

**Database Connection Errors:**
```bash
# Check PostgreSQL is running
pg_isready -h localhost -p 5432

# Check connection string
echo $DATABASE_URL
```

**Redis Connection Errors:**
```bash
# Check Redis is running
redis-cli ping

# Check connection string
echo $REDIS_URL
```

**WebSocket Authentication Failures:**
- Ensure JWT secret matches between API and WebSocket servers
- Check token expiration time
- Verify query parameter format: `?token=jwt_token`

**Session Capacity Issues:**
- Default max participants per session: 50
- Configurable via `APP__APP__MAX_PARTICIPANTS_PER_SESSION`

### Performance Tuning

**Database Connection Pool:**
```bash
APP__DATABASE__MAX_CONNECTIONS=20
APP__DATABASE__MIN_CONNECTIONS=5
```

**Redis Connection Pool:**
```bash
APP__REDIS__MAX_CONNECTIONS=20
```

**Location Data TTL:**
```bash
APP__APP__LOCATION_TTL_SECONDS=30
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Code Standards
- Use `rustfmt` for formatting
- Use `clippy` for linting
- Write comprehensive tests
- Document public APIs
- Follow conventional commit messages

## License

This project is part of the location sharing application system.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review application logs
3. Check database/Redis connectivity
4. Verify configuration settings