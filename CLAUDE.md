# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a real-time location sharing application built with **Elixir Phoenix backend** and **Flutter mobile app**. After comprehensive stress testing and complexity analysis, we selected a single-backend architecture for optimal simplicity and performance.

- **Elixir Backend** (`backend_elixir/`): Unified Phoenix application with REST API and WebSocket Channels
- **Flutter Mobile App** (`mobile_app/`): Cross-platform client for real-time location sharing

## Commands

### Full Stack Operations
```bash
# Initial setup (run once)
./run.sh --setup

# Start full stack (Elixir backend + Flutter app + PostgreSQL)  
./run.sh --start

# Start only Flutter app (requires backend already running)
./run.sh --flutter

# Start only Elixir backend service
./run.sh --elixir

# Restart all services
./run.sh --restart

# Stop all services (backends, Flutter, Docker)
./run.sh --stop

# Check status of all services
./run.sh --status

# Run health checks on all services
./run.sh --health
```

### Backend Development
```bash
cd backend_elixir

# Dependencies and setup
mix deps.get
mix ecto.setup              # Create + migrate + seed database
mix ecto.reset              # Drop and recreate database

# Development
mix phx.server              # Start Phoenix server (port 4000)
iex -S mix phx.server       # Start with interactive shell

# Testing
mix test                    # Run all tests
mix test test/path/to/test.exs  # Run specific test file

# Code quality
mix format                  # Format code
mix credo                   # Static analysis (if available)

# Database
mix ecto.migrate            # Run migrations
mix ecto.rollback          # Rollback last migration
mix ecto.gen.migration name # Generate new migration
```

### Frontend Development
```bash
cd mobile_app

# Dependencies
flutter pub get

# Development
flutter run -d web-server --web-port 52778  # Run web server on port 52778
flutter run -d chrome       # Run in Chrome browser
flutter run                 # Run on connected device/emulator

# Testing
flutter test                # Run all tests
flutter test test/unit_test.dart  # Run specific test

# Code quality
flutter analyze             # Static analysis
dart format .              # Format code
```

## Architecture

### Elixir-Only Architecture
Single Phoenix application providing all backend services:
- **REST API**: Session management, participant handling, authentication
- **WebSocket Channels**: Real-time location updates and broadcasting
- **BEAM Processes**: Session coordination and state management without external dependencies

### Infrastructure
- **Database**: PostgreSQL for session and participant data
- **State Management**: Pure BEAM processes (no Redis dependency)
- **Fault Tolerance**: OTP supervision trees for automatic recovery

### Backend Architecture (Elixir/Phoenix)

The backend follows Phoenix's layered architecture with database-only state management:

1. **Application Supervision Tree** (`lib/location_sharing/application.ex`)
   - Sessions.Supervisor: Manages session cleanup processes
   - Phoenix.PubSub: Real-time message broadcasting
   - Telemetry: Metrics collection
   - Repo: PostgreSQL connection pool

2. **Web Layer** (`lib/location_sharing_web/`)
   - **Router**: Defines REST endpoints and channel routes
   - **Controllers**: Handle HTTP requests
     - SessionController: Session CRUD operations
     - ParticipantController: Join/leave management
     - HealthController: Health checks
   - **Channels**: WebSocket communication
     - LocationChannel: Real-time location updates
     - UserSocket: JWT authentication for WebSockets

3. **Business Logic** (`lib/location_sharing/`)
   - **Sessions Context**: Session lifecycle management
     - Session schema with validation
     - Participant management
     - Cleanup worker for expired sessions
   - **Database-Centric Architecture**: All state stored in PostgreSQL
     - Phoenix PubSub for real-time broadcasts
     - Direct database queries for participant counts
     - No in-memory session processes

4. **Data Flow**:
   ```
   Client → REST API → Controller → Context → PostgreSQL
                                          ↓
   Client ← WebSocket ← Channel ← PubSub ← Database
   ```

### Frontend Architecture (Flutter)

The mobile app uses Riverpod for state management:

1. **State Management** (`lib/providers/`)
   - SessionProvider: Session state and lifecycle
   - LocationProvider: GPS tracking (2-second updates)
   - ParticipantsProvider: Real-time participant tracking

2. **Service Layer** (`lib/services/`)
   - ApiService: REST communication with retry logic
   - WebSocketService: Phoenix Channels integration
   - LocationService: GPS with battery optimization
   - StorageService: Local preferences

3. **Screen Flow**:
   ```
   HomeScreen → CreateSessionScreen → MapScreen
            ↘ JoinSessionScreen    ↗
   ```

4. **Real-time Communication**:
   - JWT authentication from REST API
   - WebSocket connection to Phoenix Channels
   - Location broadcasts every 2 seconds
   - Participant updates via PubSub

### Key Design Decisions

1. **Database-Only State Management**: After removing SessionServer complexity
   - All state stored in PostgreSQL for reliability
   - Phoenix PubSub for real-time message broadcasting  
   - No in-memory GenServer processes for session state
   - Direct database queries for participant counts and session data

2. **Ephemeral Sessions**: No user accounts required
   - Unique session IDs with automatic generation
   - Automatic expiration after 24 hours (configurable)
   - Manual departure support via REST API

3. **WebSocket Protocol**: Phoenix Channels with JWT authentication
   - Automatic reconnection
   - Heartbeat monitoring via ping/pong
   - Real-time location updates every 2 seconds

## Development Workflow

### Adding Features
1. Backend: Update schema → Add context functions → Implement controller/channel
2. Frontend: Update models → Add service methods → Build UI
3. Test both components independently, then integration

### Database Changes
```bash
cd backend_elixir
mix ecto.gen.migration add_feature_name
# Edit migration file in priv/repo/migrations/
mix ecto.migrate
```

### Environment Configuration
- Backend: `backend_elixir/config/*.exs` files
- Frontend: `mobile_app/lib/config/app_config.dart`
- Google Maps: `mobile_app/.env` (copy from `.env.example`)

### Service Ports
- Elixir Phoenix: `localhost:4000`
- Flutter Web Server: `localhost:52778` 
- PostgreSQL: `localhost:5432`

### Logs
- Backend: `backend_elixir/elixir_server.log`
- Frontend: `mobile_app/flutter_server.log`

## Core Features (MVP)
- Ephemeral session creation with shareable links
- Real-time location sharing via WebSocket
- Dynamic map view with all participants
- No-signup session joining
- Manual session departure

## Development Notes

### Session Management
Sessions are ephemeral and temporary by design:
- Unique session ID generation  
- Real-time participant tracking via database + PubSub
- Automatic cleanup on session end

### WebSocket Architecture
Phoenix Channels with built-in PubSub for real-time communication:
- Location updates broadcast to session participants
- Join/leave notifications
- Connection health monitoring

### Database Schema
PostgreSQL stores:
- Session metadata (name, expiration, creator)
- Participant information (display name, avatar, activity)
- All state is persistent and database-driven

### State Management
Database-centric approach provides reliable coordination:
- All session state in PostgreSQL
- Phoenix PubSub for message broadcasting
- Direct database queries for participant counts
- No complex in-memory state to maintain

## Testing

### API-Based Testing (Recommended)
The preferred way to test the application is using API-based testing, which creates sessions and participants programmatically:

```bash
cd testing

# Run basic API test (2 sessions, 3 participants each)
./run-api-tests.sh basic

# Run with auto-start services
./run-api-tests.sh --start-backend --start-flutter basic

# Run stress test
./run-api-tests.sh stress

# Available scenarios:
# - basic: 2 sessions with 3 participants each
# - small: 1 session with 2 participants  
# - medium: 3 sessions with 5 participants each
# - stress: 5 sessions with 8 participants each
# - geographic: 3 location-themed sessions
```

### UI-Based Visual Testing
For visual regression testing with automated browsers:

```bash
cd testing/visual-tests

# Run quick visual test
./quick-test.sh

# Run full visual test suite
./run-visual-tests.sh --scenario medium
```

Note: UI-based testing spawns multiple browser instances and is resource-intensive. Use API-based testing for most scenarios.

### Location Simulator
Simulate participant movement for testing:

```bash
cd testing

# Create test sessions first
./run-api-tests.sh basic

# Run location simulator with generated session data
node location-simulator.js session-data-basic.json
```

## Troubleshooting

### WebSocket/Location Issues
1. **Location updates not visible**: Check browser console for Phoenix Channel errors
2. **WebSocket disconnections**: Verify JWT token is valid and not expired
3. **Missing participants**: Ensure Phoenix Channel join succeeded (look for "channel_joined" message)

### Phoenix Channel Message Format
The WebSocket service handles Phoenix Channel protocol:
- Outgoing: `{topic, event, payload, ref}`
- Incoming: Automatic conversion between `lat/lng` and `latitude/longitude`
- Join flow: Automatic `phx_join` on connection