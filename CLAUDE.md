# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Real-time location sharing application built with **Elixir Phoenix** backend and **Flutter** mobile app. After comprehensive stress testing and complexity analysis, the project uses a single-backend architecture for optimal simplicity and performance.

- **Elixir Backend** (`backend_elixir/`): Unified Phoenix application with REST API and WebSocket Channels
- **Flutter Mobile App** (`mobile_app/`): Cross-platform client for real-time location sharing

## Commands

### Full Stack Operations
```bash
# Initial setup (run once)
./run.sh --setup

# Start Elixir backend + Flutter app  
./run.sh --start

# Start only Flutter app (requires backend already running)
./run.sh --flutter-only

# Start only Elixir backend service
./run.sh --backend-elixir

# Stop all services (backends, Flutter, Docker)
./run.sh --stop

# Check status of all services
./run.sh --status

# Restore database to clean state
./run.sh --restore
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

### Backend Architecture (Elixir/Phoenix)

The backend follows Phoenix's layered architecture with OTP supervision:

1. **Application Supervision Tree** (`lib/location_sharing/application.ex`)
   - Sessions.Supervisor: Manages dynamic session processes
   - Phoenix.PubSub: Real-time message broadcasting
   - PromEx: Metrics collection
   - Repo: Database connection pool

2. **Web Layer** (`lib/location_sharing_web/`)
   - **Router**: Defines REST endpoints and channel routes
   - **Controllers**: Handle HTTP requests
     - SessionController: Session CRUD operations
     - ParticipantController: Join/leave management
     - HealthController: Kubernetes-ready health checks
   - **Channels**: WebSocket communication
     - LocationChannel: Real-time location updates
     - UserSocket: JWT authentication for WebSockets

3. **Business Logic** (`lib/location_sharing/`)
   - **Sessions Context**: Session lifecycle management
     - Session schema with validation
     - Participant management
     - Cleanup worker for expired sessions
   - **Process Architecture**: Each session runs as supervised GenServer
     - Registry tracks active processes
     - Fault tolerance via supervision trees
     - No external state dependencies (pure BEAM)

4. **Data Flow**:
   ```
   Client → REST API → Controller → Context → Database
                                          ↓
   Client ← WebSocket ← Channel ← PubSub ← GenServer
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

1. **Elixir-Only Architecture**: Single Phoenix app provides all services
   - REST API + WebSocket in one deployment
   - BEAM processes for state (no Redis)
   - OTP supervision for fault tolerance

2. **Ephemeral Sessions**: No user accounts required
   - Unique session IDs
   - Automatic expiration after 24 hours
   - Manual departure support

3. **WebSocket Protocol**: Phoenix Channels with built-in features
   - Automatic reconnection
   - Heartbeat monitoring
   - Message guarantees

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
- PostgreSQL: `localhost:5432`

### Logs
- Backend: `backend_elixir/elixir_server.log`
- Frontend: `mobile_app/flutter_app.log`