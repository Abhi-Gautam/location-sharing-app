#!/bin/bash

# Quick Visual Test - Simplified API-based testing with dashboard integration
# Usage: ./quick-test.sh [users] [sessions] [duration]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'  
BLUE='\033[0;34m'
NC='\033[0m'

USERS=${1:-10}
SESSIONS=${2:-1}
DURATION=${3:-180}

echo -e "${BLUE}🚀 Starting Quick Visual Test${NC}"
echo -e "${BLUE}Users: $USERS | Sessions: $SESSIONS | Duration: ${DURATION}s${NC}"
echo -e "${GREEN}📊 Dashboard: http://localhost:3001${NC}"
echo -e "${GREEN}🗺️  Live Map: http://localhost:3001/map${NC}"
echo -e "${GREEN}📈 Metrics: http://localhost:3001/metrics${NC}"
echo ""

# Check if dashboard is running
if ! curl -s http://localhost:3001 > /dev/null 2>&1; then
    echo -e "${RED}❌ Dashboard not running. Starting it...${NC}"
    npm run dashboard > dashboard.log 2>&1 &
    sleep 3
fi

# Run the API test
echo -e "${BLUE}▶️  Running API test coordinator...${NC}"
node api-test-coordinator.js $USERS $SESSIONS $DURATION