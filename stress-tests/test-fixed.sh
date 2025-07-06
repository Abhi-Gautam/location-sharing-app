#!/bin/bash

# Fixed WebSocket test runner
# Usage: ./test-fixed.sh [rust|elixir] [baseline|load_test]

set -e

BACKEND=${1:-rust}
SCENARIO=${2:-baseline}

echo "🚀 Running FIXED WebSocket test"
echo "Backend: $BACKEND"
echo "Scenario: $SCENARIO"
echo "Duration: 1 minute (baseline) for quick iteration"
echo ""

# Set environment variables
export BACKEND=$BACKEND
export SCENARIO=$SCENARIO

case $BACKEND in
  "rust")
    export API_URL="http://rust-api:8000"
    export WS_URL="ws://rust-ws:8001"
    ;;
  "elixir") 
    export API_URL="http://elixir:4000"
    export WS_URL="ws://elixir:4000/socket/websocket"
    ;;
  *)
    echo "❌ Invalid backend: $BACKEND (use 'rust' or 'elixir')"
    exit 1
    ;;
esac

echo "API URL: $API_URL"
echo "WebSocket URL: $WS_URL"
echo ""

# Run the fixed test
cd /Users/abhishekgautam/System\ Design\ Projects/location-sharing/stress-tests

docker run --rm -i \
  --network location-sharing_test_network \
  -v "$(pwd)/k6:/scripts" \
  -e BACKEND="$BACKEND" \
  -e SCENARIO="$SCENARIO" \
  -e API_URL="$API_URL" \
  -e WS_URL="$WS_URL" \
  -e K6_PROMETHEUS_RW_SERVER_URL="http://prometheus:9090/api/v1/write" \
  -e K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM="true" \
  grafana/k6:latest run \
  --out experimental-prometheus-rw \
  --tag testid="${BACKEND}_${SCENARIO}_$(date +%Y%m%d_%H%M%S)" \
  /scripts/scripts/websocket-test-fixed.js

echo ""
echo "✅ Test completed!"
echo "📊 Check Grafana dashboard: http://localhost:3000"
echo "🔍 Check Prometheus: http://localhost:9090"