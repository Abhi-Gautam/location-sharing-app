#!/bin/bash

# API Test Runner
# Runs API-based session creation for manual testing with Flutter UI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
SCENARIO="basic"
AUTO_START_BACKEND=false
AUTO_START_FLUTTER=false
VERBOSE=false
TESTING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TESTING_DIR")"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${MAGENTA}$1${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
API Test Runner

USAGE:
    $0 [OPTIONS] [SCENARIO]

SCENARIOS:
    basic       2 sessions with 3 participants each (default)
    small       1 session with 2 participants  
    medium      3 sessions with 5 participants each
    stress      5 sessions with 8 participants each
    geographic  3 location-themed sessions with 6 participants each
    all         Run all scenarios sequentially

OPTIONS:
    --start-backend     Automatically start Elixir backend if not running
    --start-flutter     Automatically start Flutter web app if not running
    --verbose          Enable verbose logging
    --help             Show this help message

EXAMPLES:
    # Run basic scenario
    $0 basic

    # Run stress test with auto-start
    $0 --start-backend --start-flutter stress

    # Run all scenarios
    $0 all

REQUIREMENTS:
    - Node.js 18+ installed
    - Elixir backend running on localhost:4000
    - Flutter web app running on localhost:52778 (optional, for manual testing)

WORKFLOW:
    1. Script creates sessions and participants via API
    2. Session IDs and details are displayed
    3. Manually open Flutter app and join sessions using displayed IDs
    4. Verify real-time location sharing works with API-created participants

EOF
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    local url=$2
    local timeout=${3:-5}
    
    if curl -s --max-time $timeout "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check backend status
check_backend() {
    print_info "Checking Elixir backend status..."
    
    if check_service "Elixir backend" "http://localhost:4000/health" 10; then
        print_success "Elixir backend is running"
        return 0
    else
        print_warning "Elixir backend is not responding"
        return 1
    fi
}

# Function to check Flutter status
check_flutter() {
    print_info "Checking Flutter web app status..."
    
    if check_service "Flutter web" "http://localhost:52778" 5; then
        print_success "Flutter web app is running"
        return 0
    else
        print_warning "Flutter web app is not responding"
        return 1
    fi
}

# Function to start backend
start_backend() {
    print_info "Starting Elixir backend..."
    
    cd "$PROJECT_ROOT"
    if [[ -f "run.sh" ]]; then
        ./run.sh --elixir &
        BACKEND_PID=$!
        
        # Wait for backend to be ready
        print_info "Waiting for backend to start..."
        local attempts=0
        local max_attempts=30
        
        while [[ $attempts -lt $max_attempts ]]; do
            if check_service "backend" "http://localhost:4000/health" 2; then
                print_success "Backend started successfully"
                return 0
            fi
            
            sleep 2
            ((attempts++))
            
            if [[ $((attempts % 5)) -eq 0 ]]; then
                print_info "Still waiting for backend... (${attempts}/${max_attempts})"
            fi
        done
        
        print_error "Backend failed to start within timeout"
        return 1
    else
        print_error "run.sh not found in project root"
        return 1
    fi
}

# Function to start Flutter
start_flutter() {
    print_info "Starting Flutter web app..."
    
    cd "$PROJECT_ROOT"
    if [[ -f "run.sh" ]]; then
        ./run.sh --flutter &
        FLUTTER_PID=$!
        
        # Wait for Flutter to be ready
        print_info "Waiting for Flutter to start..."
        local attempts=0
        local max_attempts=20
        
        while [[ $attempts -lt $max_attempts ]]; do
            if check_service "flutter" "http://localhost:52778" 2; then
                print_success "Flutter started successfully"
                return 0
            fi
            
            sleep 3
            ((attempts++))
            
            if [[ $((attempts % 3)) -eq 0 ]]; then
                print_info "Still waiting for Flutter... (${attempts}/${max_attempts})"
            fi
        done
        
        print_warning "Flutter may not be ready yet, but continuing..."
        return 0
    else
        print_error "run.sh not found in project root"
        return 1
    fi
}

# Function to run API session creator
run_session_creator() {
    local scenario=$1
    
    print_header "=== Running API Session Creator ==="
    print_info "Scenario: $scenario"
    print_info "Working directory: $TESTING_DIR"
    
    cd "$TESTING_DIR"
    
    # Check if Node.js script exists
    if [[ ! -f "api-session-creator.js" ]]; then
        print_error "api-session-creator.js not found in $TESTING_DIR"
        return 1
    fi
    
    # Check Node.js version
    if ! command -v node &> /dev/null; then
        print_error "Node.js is required but not installed"
        return 1
    fi
    
    local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ $node_version -lt 18 ]]; then
        print_warning "Node.js 18+ recommended for fetch support (current: $(node --version))"
    fi
    
    # Run the session creator
    if [[ "$VERBOSE" == "true" ]]; then
        node api-session-creator.js "$scenario"
    else
        node api-session-creator.js "$scenario" 2>/dev/null || {
            print_error "Session creator failed. Run with --verbose for details"
            return 1
        }
    fi
    
    return $?
}

# Function to display manual testing instructions
show_manual_instructions() {
    print_header "=== MANUAL TESTING INSTRUCTIONS ==="
    echo
    print_info "1. Open your browser to: http://localhost:52778"
    print_info "2. Click 'Join Session' in the Flutter app"
    print_info "3. Use one of the Session IDs displayed above"
    print_info "4. Enter your display name and join"
    print_info "5. You should see the API-created participants on the map"
    print_info "6. Test real-time location sharing and WebSocket functionality"
    echo
    print_success "Sessions are now ready for manual testing!"
}

# Function for cleanup on exit
cleanup() {
    if [[ -n $BACKEND_PID ]]; then
        print_info "Stopping backend process..."
        kill $BACKEND_PID 2>/dev/null || true
    fi
    
    if [[ -n $FLUTTER_PID ]]; then
        print_info "Stopping Flutter process..."
        kill $FLUTTER_PID 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --start-backend)
            AUTO_START_BACKEND=true
            shift
            ;;
        --start-flutter)
            AUTO_START_FLUTTER=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*|--*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$SCENARIO" || "$SCENARIO" == "basic" ]]; then
                SCENARIO="$1"
            else
                print_error "Multiple scenarios specified"
                exit 1
            fi
            shift
            ;;
    esac
done

# Main execution
print_success "🧪 API Test Runner"
echo "=================================="
echo "Scenario: $SCENARIO"
echo "Auto-start backend: $AUTO_START_BACKEND"
echo "Auto-start Flutter: $AUTO_START_FLUTTER"
echo ""

# Check and start services as needed
if ! check_backend; then
    if [[ "$AUTO_START_BACKEND" == "true" ]]; then
        if ! start_backend; then
            print_error "Failed to start backend"
            exit 1
        fi
    else
        print_error "Backend is not running. Start it with:"
        print_info "./run.sh --elixir"
        print_info "Or use --start-backend flag"
        exit 1
    fi
fi

if ! check_flutter; then
    if [[ "$AUTO_START_FLUTTER" == "true" ]]; then
        start_flutter
    else
        print_warning "Flutter is not running. For manual testing, start it with:"
        print_info "./run.sh --flutter"
        print_info "Or use --start-flutter flag"
    fi
fi

# Run the session creator
if run_session_creator "$SCENARIO"; then
    echo
    show_manual_instructions
    
    if [[ "$AUTO_START_FLUTTER" == "true" || "$AUTO_START_BACKEND" == "true" ]]; then
        echo
        print_info "Services started automatically will remain running..."
        print_info "Press Ctrl+C to stop all services and exit"
        
        # Keep script running
        while true; do
            sleep 10
        done
    fi
else
    print_error "Failed to create test scenario"
    exit 1
fi