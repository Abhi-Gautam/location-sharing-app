#!/bin/bash

# Test Runner Script - Run after every change to ensure everything works
# Usage: ./test-runner.sh

set -e

# --- Configuration ---
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

# --- Test Functions ---

run_backend_tests() {
    log_info "Running backend tests..."
    cd backend_elixir
    
    if mix test; then
        log_success "✅ Backend tests passed"
        cd ..
        return 0
    else
        log_error "❌ Backend tests failed" 
        cd ..
        return 1
    fi
}

run_frontend_tests() {
    log_info "Running frontend unit tests..."
    cd mobile_app
    
    if flutter test test/unit_test.dart; then
        log_success "✅ Frontend unit tests passed"
        cd ..
        return 0
    else
        log_error "❌ Frontend unit tests failed"
        cd ..
        return 1
    fi
}

run_health_checks() {
    log_info "Running service health checks..."
    
    # Check if services are running
    if ! ./run.sh --health > /dev/null 2>&1; then
        log_warning "⚠️  Services may not be running. Starting services..."
        ./run.sh --start > /dev/null 2>&1
        sleep 5
    fi
    
    if ./run.sh --health > /dev/null 2>&1; then
        log_success "✅ All services are healthy"
        return 0
    else
        log_error "❌ Service health check failed"
        return 1
    fi
}

basic_integration_test() {
    log_info "Running basic integration test..."
    
    # Basic API test - create session
    if curl -s -X POST http://localhost:4000/api/sessions \
        -H "Content-Type: application/json" \
        -d '{"name": "Test Session"}' | grep -q "session_id"; then
        log_success "✅ Basic API integration test passed"
        return 0
    else
        log_error "❌ Basic API integration test failed"
        return 1
    fi
}

run_visual_tests() {
    log_info "Running quick visual test validation..."
    
    # Check if visual testing is available
    if [[ ! -f "testing/visual-tests/package.json" ]]; then
        log_warning "⚠️  Visual testing framework not available, skipping"
        return 0
    fi
    
    # Run a quick 10-user, 30-second visual test
    cd testing/visual-tests
    
    if ./run-visual-tests.sh --users 5 --duration 30 --no-dashboard > visual-test.log 2>&1; then
        log_success "✅ Quick visual test passed"
        cd ../..
        return 0
    else
        log_warning "⚠️  Quick visual test failed (see testing/visual-tests/visual-test.log)"
        cd ../..
        return 1
    fi
}

# --- Main Test Runner ---

main() {
    log_info "🚀 Starting comprehensive test run..."
    echo "=================================="
    
    local failed_tests=0
    
    # Run backend tests
    if ! run_backend_tests; then
        ((failed_tests++))
    fi
    
    # Run frontend tests  
    if ! run_frontend_tests; then
        ((failed_tests++))
    fi
    
    # Run health checks
    if ! run_health_checks; then
        ((failed_tests++))
    fi
    
    # Run basic integration test
    if ! basic_integration_test; then
        ((failed_tests++))
    fi
    
    # Run quick visual test (non-critical)
    if ! run_visual_tests; then
        log_info "ℹ️  Visual test failed but continuing (non-critical)"
    fi
    
    echo "=================================="
    
    if [ $failed_tests -eq 0 ]; then
        log_success "🎉 All tests passed! Ready to deploy."
        return 0
    else
        log_error "💥 $failed_tests test suite(s) failed."
        return 1
    fi
}

# Run main function
main "$@"