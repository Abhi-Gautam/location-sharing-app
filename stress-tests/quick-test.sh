#!/bin/bash

# Quick Test Script for Development and Verification
# Usage: ./quick-test.sh [backend] [test_type]
# Examples:
#   ./quick-test.sh rust websocket
#   ./quick-test.sh elixir api
#   ./quick-test.sh both baseline

set -e

# Default values
BACKEND=${1:-rust}
TEST_TYPE=${2:-baseline}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Quick Stress Test Verification     ${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${GREEN}Configuration:${NC}"
echo -e "  Backend: ${BACKEND}"
echo -e "  Test Type: ${TEST_TYPE}"
echo ""

# Check if environment is running
echo -e "${YELLOW}Checking test environment...${NC}"
if ! docker-compose -f ../docker-compose.test.yml ps | grep -q "Up"; then
    echo -e "${YELLOW}Starting test environment...${NC}"
    docker-compose -f ../docker-compose.test.yml up -d
    sleep 30
fi

# Wait for backend to be ready
if [ "${BACKEND}" = "rust" ] || [ "${BACKEND}" = "both" ]; then
    echo -e "${YELLOW}Waiting for Rust backend...${NC}"
    timeout=60
    counter=0
    while [ $counter -lt $timeout ]; do
        if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Rust backend ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
        counter=$((counter + 2))
    done
fi

if [ "${BACKEND}" = "elixir" ] || [ "${BACKEND}" = "both" ]; then
    echo -e "${YELLOW}Waiting for Elixir backend...${NC}"
    timeout=60
    counter=0
    while [ $counter -lt $timeout ]; do
        if curl -f -s http://localhost:4000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Elixir backend ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
        counter=$((counter + 2))
    done
fi

# Determine test script and scenario based on test type
case "${TEST_TYPE}" in
    "baseline"|"api")
        SCRIPT="scripts/api-load-test.js"
        SCENARIO="baseline"
        TEST_NAME="Quick API Test"
        ;;
    "websocket"|"ws")
        SCRIPT="scripts/websocket-test.js"
        SCENARIO="baseline"
        TEST_NAME="Quick WebSocket Test"
        ;;
    "redis")
        SCRIPT="scripts/redis-pubsub-test.js"
        SCENARIO="baseline"
        TEST_NAME="Quick Redis Test"
        ;;
    "multi")
        SCRIPT="scripts/multi-session-websocket-test.js"
        SCENARIO="baseline"
        TEST_NAME="Quick Multi-Session Test"
        ;;
    "comparison")
        SCRIPT="scripts/backend-comparison-test.js"
        SCENARIO="baseline"
        TEST_NAME="Quick Backend Comparison"
        BACKEND="both"
        ;;
    *)
        echo -e "${RED}Unknown test type: ${TEST_TYPE}${NC}"
        echo "Available types: baseline, api, websocket, redis, multi, comparison"
        exit 1
        ;;
esac

# Create results directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="results/quick_${BACKEND}_${TEST_TYPE}_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}Running ${TEST_NAME}...${NC}"
echo -e "  Script: ${SCRIPT}"
echo -e "  Scenario: ${SCENARIO}"
echo -e "  Backend: ${BACKEND}"
echo ""

# Run the test
if [ "${TEST_TYPE}" = "comparison" ]; then
    # Special handling for comparison test
    docker run --rm -i \
        --network="location-sharing_test_network" \
        -v "${PWD}/k6:/scripts" \
        -v "${PWD}/${RESULTS_DIR}:/results" \
        -e SCENARIO="${SCENARIO}" \
        -e RUST_API_URL="http://rust-api:8000" \
        -e RUST_WS_URL="ws://rust-ws:8001" \
        -e ELIXIR_API_URL="http://elixir:4000" \
        -e ELIXIR_WS_URL="ws://elixir:4000/socket/websocket" \
        -e K6_PROMETHEUS_RW_SERVER_URL="http://prometheus:9090/api/v1/write" \
        -e K6_PROMETHEUS_RW_INSECURE_SKIP_TLS_VERIFY="true" \
        grafana/k6:latest run \
        --out experimental-prometheus-rw \
        --tag testid="comparison_${SCENARIO}_${TIMESTAMP}" \
        --tag scenario="${SCENARIO}" \
        --summary-export=/results/summary.json \
        /scripts/${SCRIPT}
else
    # Determine URLs based on backend
    if [ "${BACKEND}" = "rust" ]; then
        API_URL="http://rust-api:8000"
        WS_URL="ws://rust-ws:8001"
    elif [ "${BACKEND}" = "elixir" ]; then
        API_URL="http://elixir:4000"
        WS_URL="ws://elixir:4000/socket/websocket"
    fi
    
    docker run --rm -i \
        --network="location-sharing_test_network" \
        -v "${PWD}/k6:/scripts" \
        -v "${PWD}/${RESULTS_DIR}:/results" \
        -e BACKEND="${BACKEND}" \
        -e SCENARIO="${SCENARIO}" \
        -e API_URL="${API_URL}" \
        -e WS_URL="${WS_URL}" \
        -e K6_PROMETHEUS_RW_SERVER_URL="http://prometheus:9090/api/v1/write" \
        -e K6_PROMETHEUS_RW_INSECURE_SKIP_TLS_VERIFY="true" \
        grafana/k6:latest run \
        --out experimental-prometheus-rw \
        --tag testid="${BACKEND}_${SCENARIO}_${TIMESTAMP}" \
        --tag backend="${BACKEND}" \
        --tag scenario="${SCENARIO}" \
        --summary-export=/results/summary.json \
        /scripts/${SCRIPT}
fi

# Generate quick summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Quick Test Completed!              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Test: ${TEST_NAME}"
echo -e "Backend: ${BACKEND}"
echo -e "Results: ${RESULTS_DIR}"
echo ""
echo -e "${BLUE}Quick Analysis:${NC}"

# Try to extract some basic metrics from the results
if [ -f "${RESULTS_DIR}/summary.json" ]; then
    echo -e "  Summary file created: ✓"
    
    # Extract key metrics from summary
    if command -v jq >/dev/null 2>&1; then
        echo -e "  ${BLUE}Key Metrics:${NC}"
        echo -e "    Iterations: $(jq -r '.root_group.checks | length' "${RESULTS_DIR}/summary.json" 2>/dev/null || echo 'N/A')"
        echo -e "    Avg Response Time: $(jq -r '.metrics.http_req_duration.avg' "${RESULTS_DIR}/summary.json" 2>/dev/null || echo 'N/A')ms"
        echo -e "    Success Rate: $(jq -r '.metrics.checks.passes' "${RESULTS_DIR}/summary.json" 2>/dev/null || echo 'N/A')"
    fi
else
    echo -e "  ${RED}No summary file found${NC}"
fi

echo ""
echo -e "${BLUE}Monitoring URLs:${NC}"
echo -e "  Prometheus: http://localhost:9090"
echo -e "  Grafana: http://localhost:3000 (admin/admin123)"
echo ""
echo -e "${YELLOW}To run more comprehensive tests:${NC}"
echo -e "  ./run-comprehensive-tests.sh [test_suite] [backend]"
echo ""
echo -e "${YELLOW}To stop the test environment:${NC}"
echo -e "  docker-compose -f ../docker-compose.test.yml down"