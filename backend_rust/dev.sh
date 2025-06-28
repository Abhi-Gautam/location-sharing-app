#!/bin/bash

# Development startup script for Location Sharing Rust Backend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v cargo &> /dev/null; then
        log_error "Rust/Cargo is not installed. Please install Rust from https://rustup.rs/"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed. You'll need to set up PostgreSQL and Redis manually."
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose is not installed. You'll need to set up PostgreSQL and Redis manually."
    fi
    
    log_success "Requirements check completed"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    if [ ! -f .env ]; then
        log_info "Creating .env file from .env.example..."
        cp .env.example .env
        log_warning "Please edit .env file with your configuration if needed"
    else
        log_info ".env file already exists"
    fi
    
    # Source environment variables
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
    
    log_success "Environment setup completed"
}

# Start infrastructure services
start_infrastructure() {
    log_info "Starting infrastructure services..."
    
    if command -v docker-compose &> /dev/null; then
        log_info "Starting PostgreSQL and Redis with Docker Compose..."
        docker-compose up -d postgres redis
        
        # Wait for services to be ready
        log_info "Waiting for services to start..."
        sleep 10
        
        # Check if services are running
        if docker-compose ps postgres | grep -q "Up"; then
            log_success "PostgreSQL is running"
        else
            log_error "Failed to start PostgreSQL"
            exit 1
        fi
        
        if docker-compose ps redis | grep -q "Up"; then
            log_success "Redis is running"
        else
            log_error "Failed to start Redis"
            exit 1
        fi
    else
        log_warning "Docker Compose not available. Please ensure PostgreSQL and Redis are running manually."
        log_info "PostgreSQL should be available at: postgresql://dev:dev123@localhost:5432/location_sharing"
        log_info "Redis should be available at: redis://localhost:6379"
    fi
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    
    # Install sqlx-cli if not present
    if ! command -v sqlx &> /dev/null; then
        log_info "Installing sqlx-cli..."
        cargo install sqlx-cli
    fi
    
    # Create database if it doesn't exist
    sqlx database create 2>/dev/null || log_info "Database already exists"
    
    # Run migrations
    if sqlx migrate run; then
        log_success "Database migrations completed"
    else
        log_error "Failed to run database migrations"
        exit 1
    fi
}

# Build the application
build_application() {
    log_info "Building application..."
    
    if cargo build; then
        log_success "Application built successfully"
    else
        log_error "Failed to build application"
        exit 1
    fi
}

# Start the application
start_application() {
    log_info "Starting application servers..."
    
    # Create log directory
    mkdir -p logs
    
    log_info "Starting API server on port 8080..."
    cargo run --bin api-server > logs/api-server.log 2>&1 &
    API_PID=$!
    
    log_info "Starting WebSocket server on port 8081..."
    cargo run --bin websocket-server > logs/websocket-server.log 2>&1 &
    WS_PID=$!
    
    # Wait a moment for servers to start
    sleep 3
    
    # Check if processes are still running
    if kill -0 $API_PID 2>/dev/null; then
        log_success "API server started (PID: $API_PID)"
    else
        log_error "API server failed to start"
        exit 1
    fi
    
    if kill -0 $WS_PID 2>/dev/null; then
        log_success "WebSocket server started (PID: $WS_PID)"
    else
        log_error "WebSocket server failed to start"
        exit 1
    fi
    
    # Save PIDs for cleanup
    echo $API_PID > .api-server.pid
    echo $WS_PID > .websocket-server.pid
}

# Cleanup function
cleanup() {
    log_info "Shutting down servers..."
    
    if [ -f .api-server.pid ]; then
        API_PID=$(cat .api-server.pid)
        if kill -0 $API_PID 2>/dev/null; then
            kill $API_PID
            log_info "API server stopped"
        fi
        rm -f .api-server.pid
    fi
    
    if [ -f .websocket-server.pid ]; then
        WS_PID=$(cat .websocket-server.pid)
        if kill -0 $WS_PID 2>/dev/null; then
            kill $WS_PID
            log_info "WebSocket server stopped"
        fi
        rm -f .websocket-server.pid
    fi
    
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    echo "🚀 Location Sharing - Rust Backend Development Setup"
    echo "===================================================="
    
    check_requirements
    setup_environment
    start_infrastructure
    run_migrations
    build_application
    start_application
    
    echo ""
    log_success "🎉 Development environment is ready!"
    echo ""
    echo "Services:"
    echo "  📡 API Server:       http://localhost:8080"
    echo "  🔄 WebSocket Server: ws://localhost:8081"
    echo "  🗄️  PostgreSQL:      postgresql://dev:dev123@localhost:5432/location_sharing"
    echo "  🔄 Redis:           redis://localhost:6379"
    echo ""
    echo "Logs:"
    echo "  📋 API Server:       tail -f logs/api-server.log"
    echo "  📋 WebSocket Server: tail -f logs/websocket-server.log"
    echo ""
    echo "API Endpoints:"
    echo "  🏥 Health Check:     GET http://localhost:8080/health"
    echo "  📄 API Docs:         See README.md for full API reference"
    echo ""
    echo "Press Ctrl+C to stop all servers"
    
    # Keep script running and monitor processes
    while true; do
        # Check if both processes are still running
        if [ -f .api-server.pid ] && [ -f .websocket-server.pid ]; then
            API_PID=$(cat .api-server.pid)
            WS_PID=$(cat .websocket-server.pid)
            
            if ! kill -0 $API_PID 2>/dev/null; then
                log_error "API server has stopped unexpectedly"
                cleanup
            fi
            
            if ! kill -0 $WS_PID 2>/dev/null; then
                log_error "WebSocket server has stopped unexpectedly"
                cleanup
            fi
        fi
        
        sleep 5
    done
}

# Handle command line arguments
case "${1:-}" in
    "clean")
        log_info "Cleaning up development environment..."
        cleanup
        docker-compose down 2>/dev/null || true
        cargo clean
        rm -rf logs/
        log_success "Cleanup completed"
        ;;
    "logs")
        if [ -f logs/api-server.log ] && [ -f logs/websocket-server.log ]; then
            tail -f logs/api-server.log logs/websocket-server.log
        else
            log_error "Log files not found. Make sure the servers are running."
        fi
        ;;
    "test")
        log_info "Running tests..."
        cargo test
        ;;
    *)
        main
        ;;
esac