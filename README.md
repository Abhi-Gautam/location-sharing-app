# Location Sharing App

A real-time location sharing application built with **Flutter** (mobile) and **Elixir Phoenix** (backend), designed for groups to share their location during activities like group travel, motorcycle rides, and social meetups.

## Quick Start

A single script is provided to manage the entire application stack.

### Available Commands

#### Full Stack Operations
```bash
# Initial setup (run once)
./run.sh --setup

# Start Elixir backend + Flutter app  
./run.sh --start
```

#### Individual Component Control
```bash
# Start only Flutter app (requires backend already running)
./run.sh --flutter-only

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

# 2. Start everything
./run.sh --start

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

### Service Information

**Ports:**
- Elixir Phoenix (API + WebSocket): `localhost:4000`
- PostgreSQL: `localhost:5432`

**Logs:**
- Flutter app: `mobile_app/flutter_app.log`
- Elixir Phoenix: `backend_elixir/elixir_server.log`

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
