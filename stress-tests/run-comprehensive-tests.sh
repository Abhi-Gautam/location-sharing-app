#!/bin/bash

# Comprehensive Stress Testing Suite
# Usage: ./run-comprehensive-tests.sh [test_suite] [backend]
# Examples:
#   ./run-comprehensive-tests.sh all
#   ./run-comprehensive-tests.sh websocket rust
#   ./run-comprehensive-tests.sh comparison
#   ./run-comprehensive-tests.sh redis elixir

set -e

# Default values
TEST_SUITE=${1:-all}
BACKEND=${2:-both}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Available test suites
TEST_SUITES=("api" "websocket" "redis" "lifecycle" "comparison" "all")
BACKENDS=("rust" "elixir" "both")

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Location Sharing Comprehensive Testing      ${NC}"
echo -e "${BLUE}================================================${NC}"

# Validate inputs
if [[ ! " ${TEST_SUITES[@]} " =~ " ${TEST_SUITE} " ]]; then
    echo -e "${RED}Error: Invalid test suite '${TEST_SUITE}'${NC}"
    echo -e "Available test suites: ${TEST_SUITES[*]}"
    exit 1
fi

if [[ ! " ${BACKENDS[@]} " =~ " ${BACKEND} " ]]; then
    echo -e "${RED}Error: Invalid backend '${BACKEND}'${NC}"
    echo -e "Available backends: ${BACKENDS[*]}"
    exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo -e "  Test Suite: ${TEST_SUITE}"
echo -e "  Backend: ${BACKEND}"
echo ""

# Function to run a specific test
run_test() {
    local script=$1
    local scenario=$2
    local backend=$3
    local test_name=$4
    
    echo -e "${CYAN}Running ${test_name} test...${NC}"
    echo -e "  Script: ${script}"
    echo -e "  Scenario: ${scenario}"
    echo -e "  Backend: ${backend}"
    echo ""
    
    # Create results directory
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RESULTS_DIR="results/${backend}_${scenario}_${TIMESTAMP}"
    mkdir -p "$RESULTS_DIR"
    
    # Determine URLs based on backend
    if [ "${backend}" = "rust" ]; then
        API_URL="http://rust-api:8000"
        WS_URL="ws://rust-ws:8001"
    elif [ "${backend}" = "elixir" ]; then
        API_URL="http://elixir:4000"
        WS_URL="ws://elixir:4000/socket/websocket"
    else
        # For comparison tests, we'll use both
        API_URL="http://rust-api:8000"
        WS_URL="ws://rust-ws:8001"
        RUST_API_URL="http://rust-api:8000"
        RUST_WS_URL="ws://rust-ws:8001"
        ELIXIR_API_URL="http://elixir:4000"
        ELIXIR_WS_URL="ws://elixir:4000/socket/websocket"
    fi
    
    # Run the test
    if [ "${script}" = "scripts/backend-comparison-test.js" ]; then
        # Special handling for comparison test
        docker run --rm -i \
            --network="location-sharing_test_network" \
            -v "${PWD}/k6:/scripts" \
            -v "${PWD}/${RESULTS_DIR}:/results" \
            -e SCENARIO="${scenario}" \
            -e RUST_API_URL="${RUST_API_URL}" \
            -e RUST_WS_URL="${RUST_WS_URL}" \
            -e ELIXIR_API_URL="${ELIXIR_API_URL}" \
            -e ELIXIR_WS_URL="${ELIXIR_WS_URL}" \
            grafana/k6:latest run \
            --out json=/results/results.json \
            --out csv=/results/results.csv \
            /scripts/${script}
    else
        docker run --rm -i \
            --network="location-sharing_test_network" \
            -v "${PWD}/k6:/scripts" \
            -v "${PWD}/${RESULTS_DIR}:/results" \
            -e BACKEND="${backend}" \
            -e SCENARIO="${scenario}" \
            -e API_URL="${API_URL}" \
            -e WS_URL="${WS_URL}" \
            grafana/k6:latest run \
            --out json=/results/results.json \
            --out csv=/results/results.csv \
            /scripts/${script}
    fi
    
    # Generate test summary
    cat > "${RESULTS_DIR}/test-summary.md" << EOF
# ${test_name} Test Summary

## Test Configuration
- **Test Suite**: ${TEST_SUITE}
- **Test Name**: ${test_name}
- **Script**: ${script}
- **Scenario**: ${scenario}
- **Backend**: ${backend}
- **Timestamp**: ${TIMESTAMP}

## Test Results
Results are available in the following files:
- \`results.json\` - Detailed JSON results
- \`results.csv\` - CSV format for analysis
- \`test-summary.md\` - This summary

## Monitoring URLs
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)

## Generated
$(date)
EOF

    echo -e "${GREEN}✓ ${test_name} test completed${NC}"
    echo -e "  Results: ${RESULTS_DIR}"
    echo ""
    
    # Brief pause between tests
    sleep 5
}

# Function to check environment
check_environment() {
    echo -e "${YELLOW}Checking test environment...${NC}"
    
    # Check if Docker Compose is running
    if ! docker-compose -f ../docker-compose.test.yml ps | grep -q "Up"; then
        echo -e "${YELLOW}Starting test environment (this may take a few minutes)...${NC}"
        docker-compose -f ../docker-compose.test.yml up -d
        echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
        sleep 60
    else
        echo -e "${GREEN}Test environment is already running${NC}"
    fi
    
    # Wait for backends to be ready
    if [[ "${BACKEND}" == "rust" || "${BACKEND}" == "both" ]]; then
        echo -e "${YELLOW}Waiting for Rust backend...${NC}"
        timeout=120
        counter=0
        while [ $counter -lt $timeout ]; do
            if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Rust backend is ready${NC}"
                break
            fi
            echo -n "."
            sleep 2
            counter=$((counter + 2))
        done
        
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}Timeout waiting for Rust backend${NC}"
            exit 1
        fi
    fi
    
    if [[ "${BACKEND}" == "elixir" || "${BACKEND}" == "both" ]]; then
        echo -e "${YELLOW}Waiting for Elixir backend...${NC}"
        timeout=120
        counter=0
        while [ $counter -lt $timeout ]; do
            if curl -f -s http://localhost:4000/health > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Elixir backend is ready${NC}"
                break
            fi
            echo -n "."
            sleep 2
            counter=$((counter + 2))
        done
        
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}Timeout waiting for Elixir backend${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Environment check completed${NC}"
    echo ""
}

# Function to run API tests
run_api_tests() {
    local backend=$1
    echo -e "${PURPLE}=== API Test Suite ===${NC}"
    
    run_test "scripts/api-load-test.js" "baseline" "$backend" "API Baseline"
    run_test "scripts/api-load-test.js" "load_test" "$backend" "API Load"
    run_test "scripts/api-load-test.js" "stress_test" "$backend" "API Stress"
    run_test "scripts/api-load-test.js" "spike_test" "$backend" "API Spike"
}

# Function to run WebSocket tests
run_websocket_tests() {
    local backend=$1
    echo -e "${PURPLE}=== WebSocket Test Suite ===${NC}"
    
    run_test "scripts/websocket-test.js" "baseline" "$backend" "WebSocket Baseline"
    run_test "scripts/websocket-test.js" "websocket_connection_storm" "$backend" "WebSocket Storm"
    run_test "scripts/websocket-test.js" "location_update_flood" "$backend" "Location Update Flood"
    run_test "scripts/multi-session-websocket-test.js" "multi_session_load" "$backend" "Multi-Session WebSocket"
}

# Function to run Redis tests
run_redis_tests() {
    local backend=$1
    echo -e "${PURPLE}=== Redis Pub/Sub Test Suite ===${NC}"
    
    run_test "scripts/redis-pubsub-test.js" "redis_stress_test" "$backend" "Redis Pub/Sub Stress"
    run_test "scripts/redis-pubsub-test.js" "multi_session_load" "$backend" "Redis Multi-Channel"
}

# Function to run lifecycle tests
run_lifecycle_tests() {
    local backend=$1
    echo -e "${PURPLE}=== Session Lifecycle Test Suite ===${NC}"
    
    run_test "scripts/session-lifecycle-test.js" "session_lifecycle_stress" "$backend" "Session Lifecycle"
    run_test "scripts/session-lifecycle-test.js" "load_test" "$backend" "Session Turnover"
}

# Function to run comparison tests
run_comparison_tests() {
    echo -e "${PURPLE}=== Backend Comparison Test Suite ===${NC}"
    
    run_test "scripts/backend-comparison-test.js" "backend_comparison" "both" "Backend Comparison"
    run_test "scripts/api-load-test.js" "load_test" "rust" "Rust API Performance"
    run_test "scripts/api-load-test.js" "load_test" "elixir" "Elixir API Performance"
    run_test "scripts/websocket-test.js" "websocket_connection_storm" "rust" "Rust WebSocket Performance"
    run_test "scripts/websocket-test.js" "websocket_connection_storm" "elixir" "Elixir WebSocket Performance"
}

# Function to generate comprehensive report
generate_comprehensive_report() {
    echo -e "${YELLOW}Generating comprehensive test report...${NC}"
    
    REPORT_DIR="results/comprehensive_report_$(date +"%Y%m%d_%H%M%S")"
    mkdir -p "$REPORT_DIR"
    
    cat > "${REPORT_DIR}/comprehensive-test-report.md" << EOF
# Comprehensive Stress Testing Report

## Test Execution Summary
- **Test Suite**: ${TEST_SUITE}
- **Backend**: ${BACKEND}
- **Execution Date**: $(date)
- **Total Test Duration**: $(date)

## Test Environment
- **Docker Compose**: docker-compose.test.yml
- **Monitoring**: Prometheus + Grafana
- **Load Testing**: K6

## Test Results Overview

### Test Suite: ${TEST_SUITE}
All individual test results are stored in their respective directories under \`results/\`.

### Key Metrics to Review
1. **Response Times**: p50, p95, p99 latencies
2. **Throughput**: Requests/messages per second
3. **Error Rates**: HTTP and WebSocket error percentages
4. **Resource Usage**: CPU, Memory, Network utilization
5. **Redis Performance**: Pub/sub latency and throughput
6. **Database Performance**: Query response times

### Monitoring Dashboards
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)

### Next Steps
1. Review individual test results in their respective directories
2. Analyze performance patterns in Grafana dashboards
3. Compare backend performance if comparison tests were run
4. Identify bottlenecks and optimization opportunities
5. Plan production deployment based on performance characteristics

### Test Artifacts
- Individual test results: \`results/[backend]_[scenario]_[timestamp]/\`
- Comprehensive report: This file
- Raw metrics: Available in Prometheus
- Dashboards: Available in Grafana

## Notes
This comprehensive testing suite provides insights into:
- Individual component performance (API, WebSocket, Redis, Database)
- Multi-user session behavior
- Backend comparison (if applicable)
- Realistic user behavior patterns
- System performance under various load conditions

Generated: $(date)
EOF

    echo -e "${GREEN}✓ Comprehensive report generated: ${REPORT_DIR}/comprehensive-test-report.md${NC}"
}

# Main execution logic
main() {
    check_environment
    
    case "${TEST_SUITE}" in
        "api")
            if [ "${BACKEND}" = "both" ]; then
                run_api_tests "rust"
                run_api_tests "elixir"
            else
                run_api_tests "${BACKEND}"
            fi
            ;;
        "websocket")
            if [ "${BACKEND}" = "both" ]; then
                run_websocket_tests "rust"
                run_websocket_tests "elixir"
            else
                run_websocket_tests "${BACKEND}"
            fi
            ;;
        "redis")
            if [ "${BACKEND}" = "both" ]; then
                run_redis_tests "rust"
                run_redis_tests "elixir"
            else
                run_redis_tests "${BACKEND}"
            fi
            ;;
        "lifecycle")
            if [ "${BACKEND}" = "both" ]; then
                run_lifecycle_tests "rust"
                run_lifecycle_tests "elixir"
            else
                run_lifecycle_tests "${BACKEND}"
            fi
            ;;
        "comparison")
            run_comparison_tests
            ;;
        "all")
            echo -e "${PURPLE}=== Running ALL Test Suites ===${NC}"
            if [ "${BACKEND}" = "both" ]; then
                run_api_tests "rust"
                run_api_tests "elixir"
                run_websocket_tests "rust"
                run_websocket_tests "elixir"
                run_redis_tests "rust"
                run_redis_tests "elixir"
                run_lifecycle_tests "rust"
                run_lifecycle_tests "elixir"
                run_comparison_tests
            else
                run_api_tests "${BACKEND}"
                run_websocket_tests "${BACKEND}"
                run_redis_tests "${BACKEND}"
                run_lifecycle_tests "${BACKEND}"
            fi
            ;;
    esac
    
    generate_comprehensive_report
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}    Comprehensive Testing Completed!           ${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo -e "Test Suite: ${TEST_SUITE}"
    echo -e "Backend: ${BACKEND}"
    echo ""
    echo -e "${BLUE}Monitoring URLs:${NC}"
    echo -e "  Prometheus: http://localhost:9090"
    echo -e "  Grafana: http://localhost:3000 (admin/admin123)"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "  1. Review individual test results in results/ directory"
    echo -e "  2. Analyze performance dashboards in Grafana"
    echo -e "  3. Compare backend performance metrics"
    echo -e "  4. Identify optimization opportunities"
    echo ""
    echo -e "${YELLOW}To stop the test environment:${NC}"
    echo -e "  docker-compose -f ../docker-compose.test.yml down"
}

# Run main function
main