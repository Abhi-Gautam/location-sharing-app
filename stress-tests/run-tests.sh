#!/bin/bash

# Stress Testing Execution Script
# Usage: ./run-tests.sh [backend] [scenario] [test_type]
# Examples:
#   ./run-tests.sh rust baseline api
#   ./run-tests.sh elixir stress_test websocket
#   ./run-tests.sh rust websocket_connection_storm websocket

set -e

# Default values
BACKEND=${1:-rust}
SCENARIO=${2:-baseline}
TEST_TYPE=${3:-api}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available backends
BACKENDS=("rust" "elixir")
# Available scenarios
SCENARIOS=("baseline" "load_test" "stress_test" "spike_test" "websocket_connection_storm" "location_update_flood")
# Available test types
TEST_TYPES=("api" "websocket")

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Location Sharing Stress Testing        ${NC}"
echo -e "${BLUE}============================================${NC}"

# Validate inputs
if [[ ! " ${BACKENDS[@]} " =~ " ${BACKEND} " ]]; then
    echo -e "${RED}Error: Invalid backend '${BACKEND}'${NC}"
    echo -e "Available backends: ${BACKENDS[*]}"
    exit 1
fi

if [[ ! " ${SCENARIOS[@]} " =~ " ${SCENARIO} " ]]; then
    echo -e "${RED}Error: Invalid scenario '${SCENARIO}'${NC}"
    echo -e "Available scenarios: ${SCENARIOS[*]}"
    exit 1
fi

if [[ ! " ${TEST_TYPES[@]} " =~ " ${TEST_TYPE} " ]]; then
    echo -e "${RED}Error: Invalid test type '${TEST_TYPE}'${NC}"
    echo -e "Available test types: ${TEST_TYPES[*]}"
    exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo -e "  Backend: ${BACKEND}"
echo -e "  Scenario: ${SCENARIO}"
echo -e "  Test Type: ${TEST_TYPE}"
echo ""

# Check if Docker Compose is running
echo -e "${YELLOW}Checking test environment...${NC}"
if ! docker-compose -f ../docker-compose.test.yml ps | grep -q "Up"; then
    echo -e "${YELLOW}Starting test environment (this may take a few minutes)...${NC}"
    docker-compose -f ../docker-compose.test.yml up -d
    echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
    sleep 30
    
    # Wait for specific backend to be healthy
    echo -e "${YELLOW}Waiting for ${BACKEND} backend to be ready...${NC}"
    timeout=120
    counter=0
    while [ $counter -lt $timeout ]; do
        if [ "${BACKEND}" = "rust" ]; then
            if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
                echo -e "${GREEN}Rust backend is ready${NC}"
                break
            fi
        elif [ "${BACKEND}" = "elixir" ]; then
            if curl -f -s http://localhost:4000/health > /dev/null 2>&1; then
                echo -e "${GREEN}Elixir backend is ready${NC}"
                break
            fi
        fi
        
        echo -n "."
        sleep 2
        counter=$((counter + 2))
    done
    
    if [ $counter -ge $timeout ]; then
        echo -e "${RED}Timeout waiting for ${BACKEND} backend to be ready${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Test environment is already running${NC}"
fi

# Set test script based on type
if [ "${TEST_TYPE}" = "api" ]; then
    SCRIPT="scripts/api-load-test.js"
elif [ "${TEST_TYPE}" = "websocket" ]; then
    SCRIPT="scripts/websocket-test.js"
fi

# Prepare output directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="results/${BACKEND}_${SCENARIO}_${TEST_TYPE}_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

echo -e "${YELLOW}Starting ${TEST_TYPE} test...${NC}"
echo -e "Results will be saved to: ${RESULTS_DIR}"

# Determine URLs based on backend (use container names for Docker network)
if [ "${BACKEND}" = "rust" ]; then
    API_URL="http://rust-api:8000"
    WS_URL="ws://rust-ws:8001"
elif [ "${BACKEND}" = "elixir" ]; then
    API_URL="http://elixir:4000"
    WS_URL="ws://elixir:4000/socket/websocket"
fi

# Run K6 test
echo -e "${BLUE}Executing K6 test...${NC}"
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

# Generate summary report
echo -e "${BLUE}Generating test summary...${NC}"
cat > "${RESULTS_DIR}/test-summary.md" << EOF
# Stress Test Summary

## Test Configuration
- **Backend**: ${BACKEND}
- **Scenario**: ${SCENARIO}
- **Test Type**: ${TEST_TYPE}
- **Timestamp**: ${TIMESTAMP}
- **API URL**: ${API_URL}
- **WebSocket URL**: ${WS_URL}

## Test Results
Results are available in the following files:
- \`summary.json\` - K6 test summary with key metrics
- \`test-summary.md\` - This summary

Metrics are sent directly to Prometheus for real-time monitoring.

## Monitoring
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)

## Next Steps
1. Review the results in Grafana dashboards
2. Check Prometheus metrics for detailed insights
3. Compare results between backends
4. Analyze bottlenecks and performance patterns

## Test Artifacts
Generated: $(date)
EOF

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Test completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results saved to: ${RESULTS_DIR}"
echo -e "Summary report: ${RESULTS_DIR}/test-summary.md"
echo ""
echo -e "${BLUE}Monitoring URLs:${NC}"
echo -e "  Prometheus: http://localhost:9090"
echo -e "  Grafana: http://localhost:3000 (admin/admin123)"
echo ""
echo -e "${YELLOW}To run another test:${NC}"
echo -e "  ./run-tests.sh [backend] [scenario] [test_type]"
echo ""
echo -e "${YELLOW}To stop the test environment:${NC}"
echo -e "  docker-compose -f docker-compose.test.yml down"