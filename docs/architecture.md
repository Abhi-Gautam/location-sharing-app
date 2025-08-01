# System Architecture

## 🏗️ High-Level Architecture

The Location Sharing application follows a modern, scalable architecture with clear separation of concerns.

```
┌─────────────────────────────────────────────────────────────┐
│                    Location Sharing System                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────┐  │
│  │   Flutter App   │◄──►│ Phoenix Backend │◄──►│ PostDB  │  │
│  │                 │    │                 │    │         │  │
│  │ • Mobile UI     │    │ • REST API      │    │ • Data  │  │
│  │ • WebSocket     │    │ • Channels      │    │ • State │  │
│  │ • GPS Tracking  │    │ • OTP Actors    │    │         │  │
│  │ • Google Maps   │    │ • Broadcasting  │    │         │  │
│  └─────────────────┘    └─────────────────┘    └─────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Design Principles

### 1. **Elixir-Only Backend**
After comprehensive stress testing and complexity analysis, we chose a **single Elixir Phoenix backend** for optimal simplicity and performance.

**Key Benefits**:
- ✅ **Unified Architecture**: Single codebase, deployment, monitoring
- ✅ **OTP Supervision**: Built-in fault tolerance and recovery
- ✅ **Phoenix Channels**: Native real-time WebSocket support
- ✅ **Database-Centric State**: All state in PostgreSQL for reliability
- ✅ **Horizontal Scaling**: Proven Phoenix clustering capabilities

### 2. **Database-Only State Management**
All session state is stored in PostgreSQL with Phoenix PubSub for real-time broadcasting.

**Benefits**:
- ✅ **Reliability**: Database-backed state survives restarts
- ✅ **Simplicity**: No complex in-memory state coordination
- ✅ **Scalability**: Direct database queries for participant counts
- ✅ **Debugging**: All state is inspectable and queryable

### 3. **Ephemeral Sessions**
Privacy-focused design with temporary, no-signup sessions.

**Features**:
- 🔒 **No User Accounts**: Anonymous participation
- ⏰ **Auto-Expiration**: 24-hour maximum session duration
- 🧹 **Automatic Cleanup**: Background workers remove expired data
- 🔗 **Shareable Links**: Simple session joining via URLs

## 🏢 Component Architecture

### Frontend (Flutter)

```
Flutter Mobile App
├── State Management (Riverpod)
│   ├── SessionProvider      # Session lifecycle
│   ├── LocationProvider     # GPS tracking
│   └── ParticipantsProvider # Real-time participants
├── Services
│   ├── ApiService          # REST communication
│   ├── WebSocketService    # Phoenix Channels
│   ├── LocationService     # GPS with battery optimization
│   └── StorageService      # Local preferences
├── UI Layer
│   ├── HomeScreen          # Entry point
│   ├── CreateSessionScreen # Session creation
│   ├── JoinSessionScreen   # Session joining
│   └── MapScreen           # Real-time map view
└── Data Models
    ├── Session             # Session data
    ├── Participant         # User information
    └── Location            # GPS coordinates
```

### Backend (Elixir Phoenix)

```
Phoenix Backend
├── Application Supervision Tree
│   ├── Sessions.Supervisor # Session cleanup processes
│   ├── Phoenix.PubSub     # Real-time broadcasting
│   ├── Telemetry         # Metrics collection
│   └── Repo              # PostgreSQL connection pool
├── Web Layer
│   ├── Router            # Route definitions
│   ├── Controllers       # HTTP request handling
│   │   ├── SessionController    # Session CRUD
│   │   ├── ParticipantController # Join/leave
│   │   └── HealthController     # Health checks
│   └── Channels          # WebSocket communication
│       ├── LocationChannel # Real-time updates
│       └── UserSocket     # JWT authentication
├── Business Logic
│   ├── Sessions Context  # Session management
│   │   ├── Session schema # Data validation
│   │   ├── Participant schema # User data
│   │   └── Cleanup workers # Background tasks
│   └── Database Schema
│       ├── Sessions table # Session metadata
│       └── Participants table # User information
└── Infrastructure
    ├── Guardian          # JWT authentication
    ├── Ecto             # Database abstraction
    └── Phoenix.PubSub   # Message broadcasting
```

## 🔄 Data Flow

### 1. Session Creation Flow
```
Client Request → Controller → Context → Database → Response
     ↓
Phoenix PubSub ← Database Trigger ← Session Created
     ↓
All Connected Clients ← Real-time Broadcast
```

### 2. Real-time Location Flow
```
Mobile GPS → WebSocket → Phoenix Channel → Validation
     ↓
Database Update ← Location Processing ← Channel Handler
     ↓
Phoenix PubSub ← Database Success ← Update Complete
     ↓
All Session Participants ← Real-time Broadcast
```

### 3. Participant Management Flow
```
Join Request → Authentication → Database Insert → JWT Token
     ↓
Participant Added ← Database Success ← Validation Passed
     ↓
Real-time Notification ← PubSub Broadcast ← State Change
```

## 🔌 Communication Protocols

### REST API Endpoints
```
POST   /api/sessions                    # Create session
GET    /api/sessions/:id                # Get session details
POST   /api/sessions/:id/join           # Join session
GET    /api/sessions/:id/participants   # List participants
DELETE /api/sessions/:id/participants/:user_id # Leave session
DELETE /api/sessions/:id                # End session
GET    /health                          # Health check
```

### WebSocket Channels (Phoenix)
```
# Connection
ws://localhost:4000/socket/websocket?token={jwt}

# Channels
location:session_id    # Real-time location updates
session:session_id     # Session-level events

# Message Format (Phoenix Channel Protocol)
{
  "topic": "location:session_id",
  "event": "location_update",
  "payload": {
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": 1234567890,
    "user_id": "uuid"
  },
  "ref": "1"
}
```

## 🗄️ Database Schema

### Sessions Table
```sql
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP NOT NULL,
  creator_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  CONSTRAINT valid_expiration CHECK (expires_at > created_at)
);
```

### Participants Table
```sql
CREATE TABLE participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  avatar_color VARCHAR(7) NOT NULL DEFAULT '#FF5733',
  joined_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_seen TIMESTAMP NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  UNIQUE(session_id, user_id)
);
```

## 🚦 State Management Strategy

### Database-Centric Approach
All application state is stored in PostgreSQL:

1. **Session State**: Active sessions, metadata, expiration
2. **Participant State**: Active participants, last seen timestamps
3. **No Location Storage**: Location data is only broadcast, never persisted

### Real-time Broadcasting
Phoenix PubSub handles all real-time communication:

1. **Channel Broadcasting**: Direct WebSocket message delivery
2. **Cross-Process Communication**: Reliable message delivery
3. **Scalable Design**: Supports horizontal scaling across nodes

### Background Processing
Automatic cleanup and maintenance:

1. **Session Cleanup**: Remove expired sessions every 5 minutes
2. **Participant Cleanup**: Mark inactive participants
3. **Database Maintenance**: Periodic cleanup of old data

## 🛡️ Security Architecture

### Authentication Flow
```
Client Join Request → Validate Session → Generate JWT → Store Participant
     ↓
JWT Contains: session_id, user_id, display_name, expiration
     ↓
WebSocket Connection → JWT Validation → Channel Authorization
```

### Security Measures
- ✅ **JWT Authentication**: Secure WebSocket connections
- ✅ **Input Validation**: Comprehensive parameter validation
- ✅ **SQL Injection Prevention**: Ecto parameterized queries
- ✅ **CORS Protection**: Configurable cross-origin policies
- ✅ **Session Timeouts**: Automatic cleanup of inactive sessions
- ✅ **No Permanent Data**: Location data is never stored

## 📊 Scalability Design

### Horizontal Scaling
Phoenix supports clustering for high availability:

```
Load Balancer
├── Phoenix Node 1 ──┐
├── Phoenix Node 2 ──┼── Shared PostgreSQL
└── Phoenix Node 3 ──┘
```

### Performance Characteristics
- **Session Creation**: < 50ms
- **Participant Join**: < 100ms
- **Location Updates**: < 10ms
- **WebSocket Latency**: < 5ms
- **Concurrent Users**: 1000+ per node

### Resource Usage
- **Memory**: ~50MB base + ~1KB per active participant
- **CPU**: Minimal (event-driven architecture)
- **Database**: Linear growth with active sessions/participants
- **Network**: Efficient binary WebSocket frames

## 🔧 Deployment Architecture

### Development
```
Single Machine
├── PostgreSQL (Docker)
├── Phoenix Backend (localhost:4000)
└── Flutter Web (localhost:52778)
```

### Production
```
Kubernetes Cluster
├── PostgreSQL (Managed Service)
├── Phoenix Backend (Multiple Pods)
├── Load Balancer
└── Static Asset CDN
```

## 📈 Monitoring & Observability

### Health Checks
- `/health` - Basic health status
- `/health/detailed` - Dependency checks
- `/health/ready` - Kubernetes readiness
- `/health/live` - Kubernetes liveness

### Metrics Collection
- Request duration and counts
- Database query performance
- WebSocket connection metrics
- Error rates and patterns
- Memory and CPU usage

### Logging Strategy
- Structured logging with request IDs
- Real-time error alerting
- Performance monitoring
- Audit trails for debugging

## 🚀 Technology Decisions

### Why Elixir Phoenix?
1. **Built for Real-time**: Native WebSocket and pub/sub support
2. **Fault Tolerance**: OTP supervision trees handle failures gracefully
3. **Scalability**: Proven at scale (Discord, WhatsApp backend principles)
4. **Developer Experience**: Excellent tooling and documentation
5. **Performance**: Low latency, high concurrency

### Why Flutter?
1. **Cross-platform**: Single codebase for iOS and Android
2. **Performance**: Native compilation and rendering
3. **Real-time UI**: Reactive state management with Riverpod
4. **Google Maps**: Excellent maps integration
5. **Developer Experience**: Hot reload and comprehensive tooling

### Why PostgreSQL?
1. **ACID Compliance**: Reliable data consistency
2. **JSON Support**: Flexible schema evolution
3. **Performance**: Excellent for read/write workloads
4. **Ecosystem**: Rich tooling and extensions
5. **Managed Services**: Easy deployment options

---

This architecture provides a solid foundation for real-time location sharing with room for future enhancements while maintaining simplicity and reliability.