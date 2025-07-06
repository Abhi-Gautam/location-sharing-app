#!/bin/bash

# Stress Testing Setup Verification Script
# Checks that all components are properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Stress Testing Setup Verification      ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if required files exist
echo -e "${YELLOW}Checking required files...${NC}"

REQUIRED_FILES=(
    "docker-compose.test.yml"
    "backend_rust/Dockerfile"
    "backend_elixir/Dockerfile"
    "stress-tests/k6/config/test-scenarios.json"
    "stress-tests/k6/scripts/api-load-test.js"
    "stress-tests/k6/scripts/websocket-test.js"
    "stress-tests/run-tests.sh"
    "stress-tests/compare-backends.sh"
    "monitoring/prometheus/prometheus.yml"
)

missing_files=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo -e "${RED}Missing required files. Please ensure all files are present.${NC}"
    exit 1
fi

# Check if required directories exist
echo ""
echo -e "${YELLOW}Checking required directories...${NC}"

REQUIRED_DIRS=(
    "stress-tests/results"
    "stress-tests/comparisons"
    "monitoring/grafana/provisioning"
    "monitoring/grafana/dashboards"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir"
    else
        echo -e "${YELLOW}Creating${NC} $dir"
        mkdir -p "$dir"
    fi
done

# Check Docker and Docker Compose
echo ""
echo -e "${YELLOW}Checking Docker environment...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker is installed"
    docker_version=$(docker --version)
    echo -e "    $docker_version"
else
    echo -e "${RED}✗${NC} Docker is not installed"
    echo -e "${RED}Please install Docker to continue${NC}"
    exit 1
fi

if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose is installed"
    compose_version=$(docker-compose --version)
    echo -e "    $compose_version"
else
    echo -e "${RED}✗${NC} Docker Compose is not installed"
    echo -e "${RED}Please install Docker Compose to continue${NC}"
    exit 1
fi

# Check Docker daemon
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
else
    echo -e "${RED}✗${NC} Docker daemon is not running"
    echo -e "${RED}Please start Docker and try again${NC}"
    exit 1
fi

# Check port availability
echo ""
echo -e "${YELLOW}Checking port availability...${NC}"

REQUIRED_PORTS=(3000 4000 5432 6379 8000 8001 9090 9121)

for port in "${REQUIRED_PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC}  Port $port is in use"
        echo -e "    $(lsof -Pi :$port -sTCP:LISTEN | tail -n +2)"
    else
        echo -e "${GREEN}✓${NC} Port $port is available"
    fi
done

# Check if test environment is running
echo ""
echo -e "${YELLOW}Checking current test environment...${NC}"

if docker-compose -f docker-compose.test.yml ps | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Test environment is currently running"
    echo -e "${BLUE}Running services:${NC}"
    docker-compose -f docker-compose.test.yml ps
else
    echo -e "${YELLOW}!${NC} Test environment is not currently running"
    echo -e "${BLUE}To start the test environment:${NC}"
    echo -e "    docker-compose -f docker-compose.test.yml up -d"
fi

# Test Docker Compose configuration
echo ""
echo -e "${YELLOW}Validating Docker Compose configuration...${NC}"

if docker-compose -f docker-compose.test.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Compose configuration is valid"
else
    echo -e "${RED}✗${NC} Docker Compose configuration has errors"
    echo -e "${RED}Please check docker-compose.test.yml${NC}"
    exit 1
fi

# Summary
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}    Setup Verification Summary             ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${GREEN}✓ All required files are present${NC}"
echo -e "${GREEN}✓ All required directories exist${NC}"
echo -e "${GREEN}✓ Docker environment is ready${NC}"
echo -e "${GREEN}✓ Docker Compose configuration is valid${NC}"
echo ""

# Quick start guide
echo -e "${BLUE}Quick Start Guide:${NC}"
echo ""
echo -e "${YELLOW}1. Start the test environment:${NC}"
echo -e "   docker-compose -f docker-compose.test.yml up -d"
echo ""
echo -e "${YELLOW}2. Run a single test:${NC}"
echo -e "   ./stress-tests/run-tests.sh rust baseline api"
echo ""
echo -e "${YELLOW}3. Run comprehensive comparison:${NC}"
echo -e "   ./stress-tests/compare-backends.sh"
echo ""
echo -e "${YELLOW}4. View monitoring:${NC}"
echo -e "   Prometheus: http://localhost:9090"
echo -e "   Grafana:    http://localhost:3000 (admin/admin123)"
echo ""
echo -e "${YELLOW}5. Stop the test environment:${NC}"
echo -e "   docker-compose -f docker-compose.test.yml down"
echo ""

echo -e "${GREEN}Setup verification complete! 🚀${NC}"