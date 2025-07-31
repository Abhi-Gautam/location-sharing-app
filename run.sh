#!/bin/bash

# Location Sharing App - Elixir Backend Only

set -e

# --- Configuration ---
ELIXIR_PORT=4000
FLUTTER_PORT=52778
DB_PORT=5432

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logging Functions ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Helper Functions ---
check_command() {
  command -v "$1" &>/dev/null
}

check_port() {
  if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
    return 0 # Port is in use
  else
    return 1 # Port is free
  fi
}

check_project_root() {
  if [[ ! -d "backend_elixir" || ! -d "mobile_app" ]]; then
    log_error "Please run this script from the project root directory."
    exit 1
  fi
}

start_infrastructure() {
  log_info "Starting Docker infrastructure (PostgreSQL)..."
  if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found in project root."
    exit 1
  fi

  if docker-compose up -d postgres; then
    log_success "Docker infrastructure started."
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 5
  else
    log_error "Failed to start Docker infrastructure."
    exit 1
  fi
}

# --- Main Functions ---

setup() {
  log_info "Starting project setup..."
  check_project_root

  # --- Prerequisite Checks ---
  log_info "Checking prerequisites..."
  for cmd in flutter mix docker docker-compose; do
    if ! check_command $cmd; then
      log_error "$cmd is not installed. Please install it and try again."
      exit 1
    fi
  done
  log_success "All prerequisites are installed."

  # --- Infrastructure Setup ---
  start_infrastructure

  # --- Elixir Backend Setup ---
  log_info "Setting up Elixir backend..."
  cd backend_elixir
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

  log_success "✅ Project setup is complete!"
  log_info "Run './run.sh --start' to start the application"
}

start_elixir_backend() {
  log_info "Starting Elixir backend..."
  check_project_root

  if check_port $ELIXIR_PORT; then
    log_warning "Port $ELIXIR_PORT is already in use. Elixir backend may already be running."
    return 1
  fi

  cd backend_elixir
  log_info "Starting Phoenix server at http://localhost:$ELIXIR_PORT"
  if mix phx.server > elixir_server.log 2>&1 &
  then
    cd ..
    sleep 3
    if check_port $ELIXIR_PORT; then
      log_success "Elixir backend started successfully on port $ELIXIR_PORT"
      return 0
    else
      log_error "Elixir backend failed to start properly."
      return 1
    fi
  else
    cd ..
    log_error "Failed to start Elixir backend."
    return 1
  fi
}

start_flutter_app() {
  log_info "Starting Flutter app..."
  check_project_root

  if check_port $FLUTTER_PORT; then
    log_warning "Port $FLUTTER_PORT is already in use. Flutter app may already be running."
    return 1
  fi

  cd mobile_app
  log_info "Starting Flutter web server on port $FLUTTER_PORT..."
  if flutter run -d web-server --web-port $FLUTTER_PORT > flutter_server.log 2>&1 &
  then
    cd ..
    sleep 5
    if check_port $FLUTTER_PORT; then
      log_success "Flutter app started successfully on port $FLUTTER_PORT"
      log_info "Access the app at: http://localhost:$FLUTTER_PORT"
      return 0
    else
      log_error "Flutter app failed to start properly."
      return 1
    fi
  else
    cd ..
    log_error "Failed to start Flutter app."
    return 1
  fi
}

start_full_stack() {
  log_info "Starting full application stack..."
  check_project_root

  # Start infrastructure
  start_infrastructure

  # Start Elixir backend
  if ! start_elixir_backend; then
    log_error "Failed to start Elixir backend"
    exit 1
  fi

  # Start Flutter app
  if ! start_flutter_app; then
    log_error "Failed to start Flutter app"
    exit 1
  fi

  log_success "✅ Full stack started successfully!"
  log_info "🌐 Elixir backend: http://localhost:$ELIXIR_PORT"
  log_info "📱 Flutter app: http://localhost:$FLUTTER_PORT"
  log_info "📊 Logs: backend_elixir/elixir_server.log, mobile_app/flutter_server.log"
}

stop_services() {
  log_info "Stopping all services..."

  # Stop Flutter processes
  pkill -f "flutter run" || true
  pkill -f "dart" || true

  # Stop Elixir processes
  pkill -f "mix phx.server" || true
  pkill -f "beam.smp" || true

  # Stop Docker containers
  docker-compose down || true

  log_success "All services stopped."
}

restart_services() {
  log_info "Restarting all services..."
  stop_services
  sleep 2
  start_full_stack
}

health_check() {
  log_info "Running health checks..."
  
  # Check Elixir backend health
  if check_port $ELIXIR_PORT; then
    log_info "Testing Elixir backend..."
    if curl -s http://localhost:$ELIXIR_PORT/health > /dev/null; then
      log_success "✅ Elixir backend is healthy"
    else
      log_error "❌ Elixir backend is not responding properly"
      return 1
    fi
  else
    log_error "❌ Elixir backend is not running"
    return 1
  fi

  # Check Flutter frontend
  if check_port $FLUTTER_PORT; then
    log_info "Testing Flutter frontend..."
    if curl -s http://localhost:$FLUTTER_PORT > /dev/null; then
      log_success "✅ Flutter frontend is healthy"
    else
      log_error "❌ Flutter frontend is not responding properly"
      return 1
    fi
  else
    log_error "❌ Flutter frontend is not running"
    return 1
  fi

  # Check PostgreSQL
  if check_port $DB_PORT; then
    log_success "✅ PostgreSQL is running"
  else
    log_error "❌ PostgreSQL is not running"
    return 1
  fi

  log_success "🎉 All services are healthy!"
  return 0
}

status() {
  log_info "Checking service status..."

  echo "🔍 Service Status:"
  echo "=================="

  # Check Elixir backend
  if check_port $ELIXIR_PORT; then
    echo "✅ Elixir backend: Running on port $ELIXIR_PORT"
  else
    echo "❌ Elixir backend: Not running"
  fi

  # Check PostgreSQL
  if check_port $DB_PORT; then
    echo "✅ PostgreSQL: Running on port $DB_PORT"
  else
    echo "❌ PostgreSQL: Not running"
  fi

  # Check Flutter web server
  if check_port $FLUTTER_PORT; then
    echo "✅ Flutter app: Running on port $FLUTTER_PORT"
  else
    echo "❌ Flutter app: Not running"
  fi

  echo "=================="
}

show_help() {
  echo "Location Sharing App - Management Script"
  echo ""
  echo "Usage: $0 [COMMAND]"
  echo ""
  echo "Commands:"
  echo "  --setup              Initial project setup (run once)"
  echo "  --start              Start full application (Elixir + Flutter)"
  echo "  --elixir             Start only Elixir backend"
  echo "  --flutter            Start only Flutter app"
  echo "  --stop               Stop all services"
  echo "  --restart            Restart all services"
  echo "  --status             Check service status"
  echo "  --health             Run health checks on all services"
  echo "  --test               Run API-based tests (recommended)"
  echo "  --test-api           Run API-based tests"
  echo "  --test-ui            Run UI-based visual tests (resource intensive)"
  echo "  --help               Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --setup          # First time setup"
  echo "  $0 --start          # Start everything"
  echo "  $0 --restart        # Restart everything"
  echo "  $0 --status         # Check what's running"
  echo "  $0 --health         # Test if services are working"
  echo "  $0 --test           # Run API-based tests"
  echo "  $0 --stop           # Stop everything"
}

# --- Main Script Logic ---

if [ $# -eq 0 ]; then
  log_error "No command provided."
  show_help
  exit 1
fi

case "$1" in
  --setup)
    setup
    ;;
  --start)
    start_full_stack
    ;;
  --elixir)
    start_infrastructure
    start_elixir_backend
    ;;
  --flutter)
    start_flutter_app
    ;;
  --stop)
    stop_services
    ;;
  --restart)
    restart_services
    ;;
  --status)
    status
    ;;
  --health)
    health_check
    ;;
  --test|--test-api)
    log_info "Running API-based tests..."
    cd testing
    if [[ -f "run-api-tests.sh" ]]; then
      ./run-api-tests.sh basic
    else
      log_error "run-api-tests.sh not found in testing directory"
      exit 1
    fi
    ;;
  --test-ui)
    log_warning "UI-based testing is resource intensive"
    log_info "Running UI-based visual tests..."
    cd testing
    if [[ -f "run-ui-tests.sh" ]]; then
      ./run-ui-tests.sh
    else
      log_error "run-ui-tests.sh not found in testing directory"
      exit 1
    fi
    ;;
  --help)
    show_help
    ;;
  *)
    log_error "Unknown command: $1"
    show_help
    exit 1
    ;;
esac