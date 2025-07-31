#!/bin/bash

# UI-Based Visual Testing Runner
# Runs browser-based visual tests using Puppeteer
# WARNING: Resource intensive - spawns multiple browser instances

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
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
UI-Based Visual Testing Runner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --scenario SCENARIO    Test scenario (light, medium, stress, endurance)
    --users COUNT         Number of simulated users
    --sessions COUNT      Number of sessions to create
    --duration SECONDS    Test duration in seconds
    --no-headless        Show browser windows (for debugging)
    --no-dashboard       Skip dashboard server
    --help               Show this help message

SCENARIOS:
    light       10 users, 1 session, 5 minutes (default)
    medium      50 users, 2 sessions, 10 minutes
    stress      100 users, 5 sessions, 15 minutes
    endurance   100 users, 2 sessions, 60 minutes

EXAMPLES:
    # Run default light scenario
    $0

    # Run stress test with visible browsers
    $0 --scenario stress --no-headless

    # Custom configuration
    $0 --users 25 --sessions 3 --duration 600

WARNING:
    This test spawns multiple browser instances and is resource-intensive.
    For most testing scenarios, use ./run-api-tests.sh instead.

REQUIREMENTS:
    - Node.js 18+ with Puppeteer installed
    - Elixir backend running on localhost:4000
    - Flutter web app running on localhost:52778
    - Sufficient system resources (RAM/CPU)

EOF
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is required but not installed"
        return 1
    fi
    
    # Check if visual-tests directory exists
    if [[ ! -d "$TESTING_DIR/visual-tests" ]]; then
        print_error "visual-tests directory not found"
        return 1
    fi
    
    # Check if npm packages are installed
    if [[ ! -d "$TESTING_DIR/visual-tests/node_modules" ]]; then
        print_warning "Node modules not installed. Installing..."
        cd "$TESTING_DIR/visual-tests"
        npm install
        cd "$TESTING_DIR"
    fi
    
    print_success "Prerequisites checked"
    return 0
}

# Main execution
print_header "🖥️  UI-Based Visual Testing Runner"
print_warning "⚠️  This test is resource-intensive and spawns multiple browsers"
print_info "💡 For most scenarios, use ./run-api-tests.sh instead"
echo ""

# Parse arguments
ARGS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_usage
            exit 0
            ;;
        *)
            ARGS="$ARGS $1"
            shift
            ;;
    esac
done

# Check prerequisites
if ! check_prerequisites; then
    print_error "Prerequisites check failed"
    exit 1
fi

# Change to visual-tests directory
cd "$TESTING_DIR/visual-tests"

# Check if run-visual-tests.sh exists
if [[ ! -f "run-visual-tests.sh" ]]; then
    print_error "run-visual-tests.sh not found in visual-tests directory"
    exit 1
fi

# Make sure it's executable
chmod +x run-visual-tests.sh

# Run the visual tests with passed arguments
print_info "Starting visual tests..."
./run-visual-tests.sh $ARGS