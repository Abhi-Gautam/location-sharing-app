# Location Sharing - Elixir/Phoenix Backend

Enterprise-grade real-time location sharing application built with Phoenix Framework, leveraging OTP principles for fault tolerance and the Actor model for scalable real-time systems.

## 🏗️ Architecture Overview

This Phoenix application demonstrates enterprise-level Elixir/Phoenix development with:

- **Phoenix Monolithic Architecture**: Single application handling HTTP and WebSocket traffic
- **OTP Supervision Trees**: Fault-tolerant GenServers for session management
- **Phoenix Channels**: Real-time WebSocket communication
- **Ecto**: PostgreSQL integration with robust schema design
- **Redis Integration**: Caching and pub/sub with Redix
- **JWT Authentication**: Secure WebSocket connections with Guardian
- **Comprehensive Testing**: ExUnit tests for all components

## 🚀 Features

### Real-time Location Sharing
- Anonymous participation (no account required)
- Real-time location updates via WebSocket
- 30-second TTL for location data privacy
- Up to 50 participants per session

### Session Management
- 24-hour maximum session duration
- 1-hour inactivity auto-expiration
- Creator-controlled session termination
- Automatic cleanup of expired sessions

### Enterprise-Ready
- Health check endpoints for monitoring
- Comprehensive error handling and logging
- CORS support for cross-origin requests
- Production-ready supervision trees
- Horizontal scaling capabilities

## 📋 Prerequisites

- **Elixir**: 1.14+ with OTP 25+
- **Phoenix**: 1.7.21+
- **PostgreSQL**: 13+ 
- **Redis**: 6.0+
- **Erlang/OTP**: 25+

## 🛠️ Quick Start

### 1. Install Dependencies

```bash
cd backend_elixir
mix deps.get
```

### 2. Database Setup

```bash
# Create and migrate database
mix ecto.setup

# Or run individual commands
mix ecto.create
mix ecto.migrate
```

### 3. Start Redis

```bash
# Using Docker
docker run -d -p 6379:6379 redis:7-alpine

# Or using local Redis
redis-server
```

### 4. Environment Configuration

Create `.env` file (copy from `.env.example`):

```bash
# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/location_sharing_dev

# Redis
REDIS_URL=redis://localhost:6379

# JWT Secret (generate secure key for production)
JWT_SECRET=your-super-secret-jwt-key

# Phoenix
SECRET_KEY_BASE=your-phoenix-secret-key-base
PHX_PORT=4000
```

### 5. Start the Application

```bash
# Development mode with IEx
iex -S mix phx.server

# Or standard mode
mix phx.server
```

The application will be available at `http://localhost:4000`

## 📡 API Documentation

### Base URL
```
http://localhost:4000/api
```

### Authentication
WebSocket connections require JWT tokens obtained from the join endpoint.

### REST Endpoints

#### Create Session
```http
POST /api/sessions
Content-Type: application/json

{
  "name": "Weekend Trip",              // optional
  "expires_in_minutes": 1440          // optional, default 1440 (24h)
}
```

**Response (201):**
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
GET /api/sessions/{session_id}
```

**Response (200):**
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

#### Join Session
```http
POST /api/sessions/{session_id}/join
Content-Type: application/json

{
  "display_name": "John Doe",
  "avatar_color": "#FF5733"            // optional
}
```

**Response (201):**
```json
{
  "user_id": "uuid",
  "websocket_token": "jwt-token",
  "websocket_url": "ws://localhost:4000/socket/websocket"
}
```

#### List Participants
```http
GET /api/sessions/{session_id}/participants
```

**Response (200):**
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

#### Leave Session
```http
DELETE /api/sessions/{session_id}/participants/{user_id}
```

#### End Session
```http
DELETE /api/sessions/{session_id}
```

### WebSocket API

#### Connection
```
ws://localhost:4000/socket/websocket?token={jwt_token}
```

Join location channel:
```javascript
const channel = socket.channel("location:session_id", {})
channel.join()
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

**Location Update:**
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

**Session Ended:**
```json
{
  "type": "session_ended",
  "data": {
    "reason": "expired"
  }
}
```

## 🏥 Health Checks

The application provides comprehensive health check endpoints:

- `GET /health` - Basic health status
- `GET /health/detailed` - Detailed dependency checks
- `GET /health/ready` - Kubernetes readiness probe
- `GET /health/live` - Kubernetes liveness probe

## 🧪 Testing

### Run All Tests
```bash
mix test
```

### Run Specific Test Suite
```bash
# Controller tests
mix test test/location_sharing_web/controllers/

# Channel tests  
mix test test/location_sharing_web/channels/

# Redis tests
mix test test/location_sharing/redis_test.exs
```

### Test Coverage
```bash
mix test --cover
```

## 🔧 Development

### Database Operations
```bash
# Reset database
mix ecto.reset

# Run migrations
mix ecto.migrate

# Rollback migration
mix ecto.rollback

# Generate new migration
mix ecto.gen.migration add_new_feature
```

### Interactive Development
```bash
# Start IEx with application
iex -S mix phx.server

# In IEx, you can interact with the application:
iex> alias LocationSharing.{Repo, Redis}
iex> alias LocationSharing.Sessions.Session
iex> Repo.all(Session)
iex> Redis.get_session_participants("session_id")
```

### Code Quality
```bash
# Format code
mix format

# Run static analysis (add Credo to deps)
mix credo

# Run security analysis (add Sobelow to deps)
mix sobelow
```

## 🏗️ Project Structure

```
backend_elixir/
├── config/              # Application configuration
│   ├── config.exs      # Base configuration
│   ├── dev.exs         # Development settings
│   ├── prod.exs        # Production settings
│   └── test.exs        # Test settings
├── lib/
│   ├── location_sharing/
│   │   ├── application.ex         # OTP Application
│   │   ├── repo.ex               # Ecto Repository
│   │   ├── redis.ex              # Redis operations
│   │   ├── guardian.ex           # JWT authentication
│   │   └── sessions/
│   │       ├── session.ex        # Session schema
│   │       ├── participant.ex    # Participant schema
│   │       ├── supervisor.ex     # Session supervisor
│   │       └── cleanup_worker.ex # Background cleanup
│   └── location_sharing_web/
│       ├── endpoint.ex           # Phoenix Endpoint
│       ├── router.ex             # Route definitions
│       ├── controllers/          # REST controllers
│       └── channels/             # WebSocket channels
├── priv/
│   └── repo/
│       └── migrations/          # Database migrations
└── test/                       # Test suite
```

## 🔒 Security Features

- **JWT Authentication**: Secure WebSocket connections
- **Input Validation**: Comprehensive parameter validation
- **SQL Injection Prevention**: Ecto parameterized queries
- **CORS Protection**: Configurable cross-origin policies
- **Rate Limiting**: Can be added via Phoenix middleware
- **Session Timeouts**: Automatic cleanup of inactive sessions

## 📊 Monitoring & Observability

### Logging
Structured logging with request IDs for tracing:
```elixir
Logger.info("User joined session", user_id: user_id, session_id: session_id)
```

### Metrics
Phoenix provides built-in metrics via Telemetry:
- Request duration
- Database query time  
- Channel connection counts
- Error rates

### LiveDashboard
Access real-time metrics at `http://localhost:4000/dev/dashboard` (development only)

## 🚀 Production Deployment

### Environment Variables
```bash
# Required for production
export DATABASE_URL="postgresql://user:pass@host:5432/dbname"
export REDIS_URL="redis://host:6379"
export SECRET_KEY_BASE="secure-random-key"
export JWT_SECRET="secure-jwt-key"
export PHX_HOST="your-domain.com"
export PORT="4000"
```

### Docker Deployment
```dockerfile
FROM elixir:1.15-alpine

# Install dependencies
RUN apk add --no-cache build-base git

# Set environment
ENV MIX_ENV=prod

# Copy application
WORKDIR /app
COPY . .

# Install dependencies and compile
RUN mix deps.get --only prod
RUN mix compile
RUN mix assets.deploy
RUN mix phx.gen.release

# Run the application
CMD ["mix", "phx.server"]
```

### Kubernetes Configuration
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: location-sharing-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: location-sharing-backend
  template:
    metadata:
      labels:
        app: location-sharing-backend
    spec:
      containers:
      - name: backend
        image: location-sharing-backend:latest
        ports:
        - containerPort: 4000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        livenessProbe:
          httpGet:
            path: /health/live
            port: 4000
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 4000
```

## 🔄 Data Flow

### Session Creation Flow
1. Client → POST `/api/sessions`
2. Create session in PostgreSQL
3. Update Redis activity
4. Return session details with join link

### Participant Join Flow
1. Client → POST `/api/sessions/:id/join`
2. Validate session and create participant
3. Generate JWT token
4. Add to Redis participants set
5. Broadcast join event via PubSub
6. Return WebSocket credentials

### Real-time Location Flow
1. Client connects WebSocket with JWT
2. Join location channel for session
3. Client sends location updates
4. Store in Redis with 30s TTL
5. Broadcast to all session participants
6. Update participant activity

### Session Cleanup Flow
1. Background worker runs every 5 minutes
2. Find expired sessions and inactive participants
3. Mark as inactive in PostgreSQL
4. Clean up Redis data
5. Broadcast session/participant events

## 🤝 Contributing

1. **Code Style**: Follow Elixir formatting (`mix format`)
2. **Documentation**: Add `@doc` attributes to public functions
3. **Testing**: Maintain test coverage above 90%
4. **Types**: Use `@spec` for type specifications
5. **Error Handling**: Use appropriate error types and logging

## 📞 Support

For technical support or questions:
- Review the [Phoenix Framework documentation](https://hexdocs.pm/phoenix)
- Check [Elixir documentation](https://hexdocs.pm/elixir)
- Refer to the technical specification in `TECHNICAL_SPEC.md`

## 📄 License

This project is part of a system design demonstration showcasing enterprise-grade Elixir/Phoenix development patterns and OTP principles for building fault-tolerant, real-time applications.
