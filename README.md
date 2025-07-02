# Location Sharing App

This project is a location sharing application with a Flutter mobile app and a backend that can be run with either Rust or Elixir.

## Quick Start

A single script is provided to manage the entire application stack with different scenarios and flags.

### Available Commands

#### Full Stack Operations
```bash
# Initial setup (run once)
./run.sh --setup

# Start with Rust backend + Flutter app
./run.sh --rust

# Start with Elixir backend + Flutter app  
./run.sh --elixir
```

#### Individual Component Control
```bash
# Start only Flutter app (requires backend already running)
./run.sh --flutter-only

# Start only Rust backend services
./run.sh --backend-rust

# Start only Elixir backend service
./run.sh --backend-elixir
```

#### Management Commands
```bash
# Stop all services (backends, Flutter, Docker)
./run.sh --stop

# Check status of all services
./run.sh --status

# Restore database to clean state
./run.sh --restore
```

### Usage Examples

**Development Workflow:**
```bash
# 1. First time setup
./run.sh --setup

# 2. Start everything with Rust backend
./run.sh --rust

# 3. Check what's running
./run.sh --status

# 4. Stop everything when done
./run.sh --stop
```

**Restart Only Flutter During Development:**
```bash
# Stop and restart just Flutter (keeps backend running)
./run.sh --stop
./run.sh --flutter-only
```

**Switch Between Backends:**
```bash
# Stop current backend and start Elixir instead
./run.sh --stop
./run.sh --elixir
```

### Service Information

**Ports:**
- Rust API: `localhost:8000`
- Rust WebSocket: `localhost:8001` 
- Elixir (Phoenix): `localhost:4000`
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`

**Logs:**
- Flutter app: `mobile_app/flutter_app.log`
- Rust API: `backend_rust/api_server.log`
- Rust WebSocket: `backend_rust/websocket_server.log`
- Elixir: `backend_elixir/elixir_server.log`

**Flutter Target:**
- Always runs in Chrome browser for debugging
- Chrome opens automatically when Flutter starts

### Security Configuration

**Google Maps API Key Setup:**
```bash
# 1. Copy the example environment file
cp mobile_app/.env.example mobile_app/.env

# 2. Edit .env file and add your actual Google Maps API key
# Get key from: https://console.cloud.google.com/
# Enable: Maps JavaScript API
```

**Important Security Notes:**
- ✅ API key is stored in `.env` file (not committed to git)
- ✅ `web/index.html` is auto-generated with key injection
- ✅ Template file `web/index.html.template` has no sensitive data
- ❌ Never commit `.env` file or `web/index.html` to version control

The run script automatically:
1. Loads API key from `mobile_app/.env`
2. Generates `web/index.html` from template
3. Injects key securely at runtime
