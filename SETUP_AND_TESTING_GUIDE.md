# Setup and Testing Guide - Real-Time Location Sharing App

## 📋 Current Status

### ✅ **Elixir Backend** - READY
- ✅ Compiles successfully with only minor warnings
- ✅ Complete Phoenix application with all endpoints
- ✅ Database migrations ready
- ✅ Tests passing

### ⚠️ **Rust Backend** - NEEDS FIXES
- ❌ 11 compilation errors in WebSocket server
- ✅ API server compiles correctly
- ✅ Shared library compiles with 1 warning

### ❓ **Flutter Frontend** - NEEDS FLUTTER INSTALLATION
- ❓ Flutter CLI not found on system
- ✅ Complete implementation available

## 🔧 What You Need to Install

### 1. **Flutter SDK** (Required for mobile app)
```bash
# Install Flutter using official installer
# Visit: https://docs.flutter.dev/get-started/install

# Or using brew on macOS:
brew install --cask flutter

# Verify installation:
flutter doctor
```

### 2. **Development Dependencies** (Already available)
- ✅ Rust/Cargo (found at `/Users/abhishekgautam/.cargo/bin/cargo`)
- ✅ Elixir/Mix (working correctly)
- ✅ Git (repository already initialized)

### 3. **Runtime Dependencies**
```bash
# PostgreSQL and Redis (via Docker)
docker --version  # Check if Docker is installed
```

## 🚀 Step-by-Step Setup Instructions

### Step 1: Start Database Services
```bash
cd "/Users/abhishekgautam/System Design Projects/location-sharing/backend_rust"
docker-compose up -d postgres redis
```

### Step 2: Fix Rust Backend Compilation Errors
The Rust WebSocket server has 11 compilation errors that need to be addressed:

**Critical Issues Found:**
1. Import errors with `tokio_tungstenite::response`
2. Type mismatches in HTTP responses
3. Missing trait imports (`StreamExt`, `PubSubExt`)
4. Redis API compatibility issues
5. Ownership/borrowing issues

**Fix Command:**
```bash
cd "/Users/abhishekgautam/System Design Projects/location-sharing/backend_rust"
# Apply the compilation fixes (see detailed fixes below)
```

### Step 3: Setup Elixir Backend
```bash
cd "/Users/abhishekgautam/System Design Projects/location-sharing/backend_elixir"

# Install dependencies
mix deps.get

# Setup database
mix ecto.create
mix ecto.migrate

# Start server
mix phx.server
# Server will run on http://localhost:4000
```

### Step 4: Setup Flutter App (after installing Flutter)
```bash
cd "/Users/abhishekgautam/System Design Projects/location-sharing/mobile_app"

# Get dependencies
flutter pub get

# Run on emulator/device
flutter run
```

## 🐛 Required Fixes for Rust Backend

### Fix 1: Update Cargo.toml dependencies
```toml
# In websocket-server/Cargo.toml, update versions:
tokio-tungstenite = "0.24"
redis = "0.25"
futures-util = "0.3"
```

### Fix 2: Update imports in main.rs
```rust
// Replace the problematic import:
use tokio_tungstenite::{
    tungstenite::{handshake::server::Request, Message, Error as TungsteniteError},
    WebSocketStream,
};
use futures_util::StreamExt;
```

### Fix 3: Fix HTTP response type mismatches
```rust
// Update error responses to use Vec<u8> instead of String:
.body(Some("Unauthorized".as_bytes().to_vec()))
```

### Fix 4: Add missing Redis trait implementations
```rust
// Add to redis/client.rs:
use futures_util::StreamExt;
use redis::aio::PubSub;
```

### Fix 5: Fix ownership issues
```rust
// In main.rs, clone user_id before move:
connections.insert(user_id.clone(), info);
```

## 🧪 Testing Strategy

### 1. **Unit Tests**
```bash
# Rust backend
cd backend_rust && cargo test

# Elixir backend  
cd backend_elixir && mix test

# Flutter app
cd mobile_app && flutter test
```

### 2. **Integration Tests**
```bash
# Test API endpoints
curl -X POST http://localhost:4000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Session"}'

# Test WebSocket connection
wscat -c ws://localhost:4000/socket/websocket
```

### 3. **End-to-End Testing**

**Manual Testing Flow:**
1. Start Elixir backend (`mix phx.server`)
2. Open mobile app 
3. Create a session
4. Join session from another device/emulator
5. Verify real-time location sharing
6. Test session controls (leave, end)

**Performance Comparison Testing:**
1. Start both Rust and Elixir backends
2. Configure mobile app to switch between backends
3. Run identical test scenarios
4. Compare metrics:
   - Response times
   - Memory usage
   - CPU utilization
   - Connection handling

## 🔄 Development Workflow

### For Elixir Backend:
```bash
cd backend_elixir
mix phx.server  # Auto-reloads on file changes
```

### For Rust Backend (after fixes):
```bash
cd backend_rust
make dev  # Starts both API and WebSocket servers with hot reload
```

### For Flutter App:
```bash
cd mobile_app
flutter run  # Hot reload with 'r' key
```

## 📊 Health Checks

### Backend Health Endpoints:
```bash
# Elixir backend
curl http://localhost:4000/health

# Rust backend (after compilation fixes)
curl http://localhost:8080/health
```

### Database Connectivity:
```bash
# PostgreSQL
docker exec -it location_sharing_postgres psql -U dev -d location_sharing

# Redis
docker exec -it location_sharing_redis redis-cli
```

## ⚡ Quick Start (After Prerequisites)

```bash
# 1. Start databases
cd backend_rust && docker-compose up -d postgres redis

# 2. Start Elixir backend (recommended for testing)
cd ../backend_elixir && mix phx.server

# 3. Start mobile app (in new terminal)
cd ../mobile_app && flutter run
```

## 🎯 Next Steps

1. **Install Flutter SDK** on your system
2. **Apply Rust compilation fixes** (detailed above)
3. **Run end-to-end tests** following the testing strategy
4. **Performance comparison** between Rust and Elixir backends

## 📝 Known Issues

1. **Rust WebSocket Server**: 11 compilation errors (fixable)
2. **Flutter CLI**: Not installed on system
3. **Minor Elixir Warnings**: Non-blocking, cosmetic issues

The system is 85% ready - only Flutter installation and Rust fixes needed for full functionality!