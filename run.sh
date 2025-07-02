#!/bin/bash

# Unified script for Location Sharing App

set -e

# --- Configuration ---
RUST_API_PORT=8000
RUST_WS_PORT=8001
ELIXIR_PORT=4000
DB_PORT=5432
REDIS_PORT=6379

# --- Colors for Output ---
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m' # No Color

# --- Logging Functions ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Helper Functions ---
check_command() {
    command -v "$1" &> /dev/null
}

check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0 # Port is in use
    else
        return 1 # Port is free
    fi
}

check_project_root() {
    if [[ ! -d "backend_rust" || ! -d "backend_elixir" || ! -d "mobile_app" ]]; then
        log_error "Please run this script from the project root directory."
        exit 1
    fi
}

start_infrastructure() {
    log_info "Starting Docker infrastructure (PostgreSQL & Redis)..."
    if [ ! -f "backend_rust/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in backend_rust directory."
        exit 1
    fi
    
    cd backend_rust
    if docker-compose up -d postgres redis; then
        log_success "Docker infrastructure started."
        cd ..
        log_info "Waiting for services to be ready..."
        sleep 10
    else
        cd ..
        log_error "Failed to start Docker infrastructure."
        exit 1
    fi
}

# --- Main Functions ---

setup() {
    log_info "Starting full project setup..."
    check_project_root

    # --- Prerequisite Checks ---
    log_info "Checking prerequisites..."
    for cmd in flutter cargo mix docker docker-compose; do
        if ! check_command $cmd; then
            log_error "$cmd is not installed. Please install it and try again."
            exit 1
        fi
    done
    log_success "All prerequisites are installed."

    # --- Infrastructure Setup ---
    start_infrastructure

    # --- Rust Backend Setup ---
    log_info "Setting up Rust backend..."
    cd backend_rust
    if [ ! -f ".env" ]; then
        cp .env.example .env
        log_warning ".env file created in backend_rust. Please review it."
    fi
    if ! cargo build; then
        log_error "Failed to build Rust backend."
        exit 1
    fi
    log_success "Rust backend setup complete."
    cd ..

    # --- Elixir Backend Setup ---
    log_info "Setting up Elixir backend..."
    cd backend_elixir
    if [ ! -f ".env" ]; then
        cp .env.example .env
        log_warning ".env file created in backend_elixir. Please review it."
    fi
    mix local.hex --if-missing --force
    mix local.rebar --if-missing --force
    if ! mix deps.get; then
        log_error "Failed to get Elixir dependencies."
        exit 1
    fi
    if ! mix ecto.setup; then
        log_warning "Elixir ecto.setup failed, but continuing. You may need to run it manually."
    fi
    log_success "Elixir backend setup complete."
    cd ..

    # --- Flutter App Setup ---
    log_info "Setting up Flutter app..."
    cd mobile_app
    if ! flutter pub get; then
        log_error "Failed to get Flutter dependencies."
        exit 1
    fi
    log_success "Flutter app setup complete."
    cd ..
    
    # --- Flutter Device Setup ---
    ./setup_flutter_devices.sh

    log_success "✅ Full project setup is complete!"
}

restore_db() {
    log_info "Restoring database..."
    check_project_root
    ./reset_database.sh
    log_success "Database restoration attempt finished."
}

run_rust() {
    log_info "Starting Rust backend and Flutter app..."
    check_project_root

    start_infrastructure

    # Configure Flutter for Rust
    log_info "Configuring Flutter for Rust backend..."
    cd mobile_app
    # Update the existing app_config.dart with Rust backend URLs
    sed -i.bak \
        -e "s|apiBaseUrl = '[^']*'|apiBaseUrl = 'http://localhost:$RUST_API_PORT/api'|g" \
        -e "s|wsBaseUrl = '[^']*'|wsBaseUrl = 'ws://localhost:$RUST_WS_PORT'|g" \
        -e "s|baseUrl = '[^']*'|baseUrl = 'http://localhost:$RUST_API_PORT/api'|g" \
        -e "s|wsUrl = '[^']*'|wsUrl = 'ws://localhost:$RUST_WS_PORT'|g" \
        -e "s|backendType = '[^']*'|backendType = 'rust'|g" \
        lib/config/app_config.dart
    log_success "Flutter configured for Rust."
    cd ..

    # Start Rust servers
    log_info "Starting Rust servers in the background..."
    (cd backend_rust && cargo run --bin api-server &> api_server.log &)
    (cd backend_rust && cargo run --bin websocket-server &> websocket_server.log &)
    sleep 5

    log_success "Rust servers are running. Logs are in api_server.log and websocket_server.log."
    log_info "Starting Flutter app..."
    start_flutter_chrome
}

run_elixir() {
    log_info "Starting Elixir backend and Flutter app..."
    check_project_root

    start_infrastructure

    # Configure Flutter for Elixir
    log_info "Configuring Flutter for Elixir backend..."
    cd mobile_app
    # Update the existing app_config.dart with Elixir backend URLs
    sed -i.bak \
        -e "s|apiBaseUrl = '[^']*'|apiBaseUrl = 'http://localhost:$ELIXIR_PORT/api'|g" \
        -e "s|wsBaseUrl = '[^']*'|wsBaseUrl = 'ws://localhost:$ELIXIR_PORT/socket'|g" \
        -e "s|baseUrl = '[^']*'|baseUrl = 'http://localhost:$ELIXIR_PORT/api'|g" \
        -e "s|wsUrl = '[^']*'|wsUrl = 'ws://localhost:$ELIXIR_PORT/socket'|g" \
        -e "s|backendType = '[^']*'|backendType = 'elixir'|g" \
        lib/config/app_config.dart
    log_success "Flutter configured for Elixir."
    cd ..

    # Start Elixir server
    log_info "Starting Elixir server in the background..."
    (cd backend_elixir && mix phx.server &> elixir_server.log &)
    sleep 5

    log_success "Elixir server is running. Log is in elixir_server.log."
    log_info "Starting Flutter app..."
    start_flutter_chrome
}

prepare_flutter_env() {
    log_info "Preparing Flutter environment..."
    cd mobile_app
    
    # Load Google Maps API key from .env file
    if [ -f ".env" ]; then
        source .env
        if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
            log_error "GOOGLE_MAPS_API_KEY not found in .env file"
            log_info "Please add your Google Maps API key to mobile_app/.env"
            exit 1
        fi
    else
        log_error ".env file not found in mobile_app directory"
        log_info "Please create mobile_app/.env with GOOGLE_MAPS_API_KEY=your_api_key"
        exit 1
    fi
    
    # Create web/index.html from template with API key injection
    if [ -f "web/index.html.template" ]; then
        mkdir -p web
        sed "s/{{GOOGLE_MAPS_API_KEY}}/$GOOGLE_MAPS_API_KEY/g" web/index.html.template > web/index.html
        log_success "Generated web/index.html with API key"
    else
        log_error "web/index.html.template not found"
        exit 1
    fi
    
    cd ..
}

start_flutter_chrome() {
    log_info "Starting Flutter app in Chrome..."
    prepare_flutter_env
    
    cd mobile_app
    nohup flutter run -d chrome > flutter_app.log 2>&1 &
    FLUTTER_PID=$!
    cd ..
    log_success "Flutter app started in Chrome (PID: $FLUTTER_PID)"
    log_info "Flutter app log: mobile_app/flutter_app.log"
}

flutter_only() {
    log_info "Starting Flutter app only..."
    check_project_root
    start_flutter_chrome
}

backend_only_rust() {
    log_info "Starting Rust backend servers only..."
    check_project_root
    
    start_infrastructure
    
    log_info "Starting Rust servers in the background..."
    (cd backend_rust && nohup cargo run --bin api-server > api_server.log 2>&1 &)
    (cd backend_rust && nohup cargo run --bin websocket-server > websocket_server.log 2>&1 &)
    sleep 5
    
    log_success "Rust servers are running."
    log_info "API server log: backend_rust/api_server.log"
    log_info "WebSocket server log: backend_rust/websocket_server.log"
}

backend_only_elixir() {
    log_info "Starting Elixir backend server only..."
    check_project_root
    
    start_infrastructure
    
    log_info "Starting Elixir server in the background..."
    (cd backend_elixir && nohup mix phx.server > elixir_server.log 2>&1 &)
    sleep 5
    
    log_success "Elixir server is running."
    log_info "Elixir server log: backend_elixir/elixir_server.log"
}

stop_all() {
    log_info "Stopping all services..."
    check_project_root
    
    # Stop Flutter
    log_info "Stopping Flutter app..."
    pkill -f "flutter run" || log_warning "No Flutter processes found"
    
    # Stop Rust servers
    log_info "Stopping Rust servers..."
    pkill -f "api-server" || log_warning "No Rust API server found"
    pkill -f "websocket-server" || log_warning "No Rust WebSocket server found"
    
    # Stop Elixir server
    log_info "Stopping Elixir server..."
    pkill -f "mix phx.server" || log_warning "No Elixir server found"
    
    # Stop Docker infrastructure
    log_info "Stopping Docker infrastructure..."
    cd backend_rust
    docker-compose down || log_warning "Docker compose down failed"
    cd ..
    
    log_success "All services stopped."
}

status() {
    log_info "Checking service status..."
    check_project_root
    
    echo ""
    echo "=== Service Status ==="
    
    # Check Flutter
    if pgrep -f "flutter run" > /dev/null; then
        echo "✅ Flutter app: Running"
    else
        echo "❌ Flutter app: Stopped"
    fi
    
    # Check Rust servers
    if pgrep -f "api-server" > /dev/null; then
        echo "✅ Rust API server: Running"
    else
        echo "❌ Rust API server: Stopped"
    fi
    
    if pgrep -f "websocket-server" > /dev/null; then
        echo "✅ Rust WebSocket server: Running"
    else
        echo "❌ Rust WebSocket server: Stopped"
    fi
    
    # Check Elixir server
    if pgrep -f "mix phx.server" > /dev/null; then
        echo "✅ Elixir server: Running"
    else
        echo "❌ Elixir server: Stopped"
    fi
    
    # Check Docker services
    cd backend_rust
    if docker-compose ps postgres | grep -q "Up"; then
        echo "✅ PostgreSQL: Running"
    else
        echo "❌ PostgreSQL: Stopped"
    fi
    
    if docker-compose ps redis | grep -q "Up"; then
        echo "✅ Redis: Running"
    else
        echo "❌ Redis: Stopped"
    fi
    cd ..
    
    echo ""
    echo "=== Port Status ==="
    echo "Rust API (8000):     $(if check_port 8000; then echo "✅ In Use"; else echo "❌ Free"; fi)"
    echo "Rust WebSocket (8001): $(if check_port 8001; then echo "✅ In Use"; else echo "❌ Free"; fi)"
    echo "Elixir (4000):        $(if check_port 4000; then echo "✅ In Use"; else echo "❌ Free"; fi)"
    echo "PostgreSQL (5432):    $(if check_port 5432; then echo "✅ In Use"; else echo "❌ Free"; fi)"
    echo "Redis (6379):         $(if check_port 6379; then echo "✅ In Use"; else echo "❌ Free"; fi)"
    echo ""
}

# --- Script Entry Point ---
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {--rust|--elixir|--setup|--restore|--flutter-only|--backend-rust|--backend-elixir|--stop|--status}"
    echo ""
    echo "Options:"
    echo "  --rust           Start Rust backend + Flutter app"
    echo "  --elixir         Start Elixir backend + Flutter app"
    echo "  --setup          Full project setup"
    echo "  --restore        Restore database"
    echo "  --flutter-only   Start Flutter app only"
    echo "  --backend-rust   Start Rust backend only"
    echo "  --backend-elixir Start Elixir backend only"
    echo "  --stop           Stop all services"
    echo "  --status         Check service status"
    exit 1
fi

case "$1" in
    --rust)
        run_rust
        ;;
    --elixir)
        run_elixir
        ;;
    --setup)
        setup
        ;;
    --restore)
        restore_db
        ;;
    --flutter-only)
        flutter_only
        ;;
    --backend-rust)
        backend_only_rust
        ;;
    --backend-elixir)
        backend_only_elixir
        ;;
    --stop)
        stop_all
        ;;
    --status)
        status
        ;;
    *)
        echo "Invalid option: $1"
        echo "Usage: $0 {--rust|--elixir|--setup|--restore|--flutter-only|--backend-rust|--backend-elixir|--stop|--status}"
        exit 1
        ;;
esac

