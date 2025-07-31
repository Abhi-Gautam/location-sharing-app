#!/bin/bash

# Health Monitor Script - Continuously monitor service health
# Usage: ./health-monitor.sh [--interval=30]

set -e

# --- Configuration ---
DEFAULT_INTERVAL=30
INTERVAL=${1#--interval=}
if [[ "$INTERVAL" == "$1" ]]; then
    INTERVAL=$DEFAULT_INTERVAL
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logging Functions ---
log_info() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $1"; }

# --- Health Check Functions ---

check_backend() {
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_frontend() {
    if curl -s http://localhost:52778 > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_database() {
    if nc -z localhost 5432 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

run_health_check() {
    local all_healthy=true
    
    # Check Elixir backend
    if check_backend; then
        echo -n "✅ Backend  "
    else
        echo -n "❌ Backend  "
        all_healthy=false
    fi
    
    # Check Flutter frontend
    if check_frontend; then
        echo -n "✅ Frontend  "
    else
        echo -n "❌ Frontend  "
        all_healthy=false
    fi
    
    # Check PostgreSQL
    if check_database; then
        echo -n "✅ Database"
    else
        echo -n "❌ Database"
        all_healthy=false
    fi
    
    if $all_healthy; then
        log_success " All services healthy"
        return 0
    else
        log_error " Some services unhealthy"
        return 1
    fi
}

# --- Main Monitor Loop ---

main() {
    log_info "🔍 Starting health monitoring (interval: ${INTERVAL}s)"
    log_info "Press Ctrl+C to stop"
    echo "=================================="
    
    while true; do
        run_health_check
        sleep $INTERVAL
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n\n${BLUE}[INFO]${NC} Health monitoring stopped."; exit 0' INT

# Run main function
main "$@"