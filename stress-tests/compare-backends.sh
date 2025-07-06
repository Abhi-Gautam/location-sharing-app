#!/bin/bash

# Backend Comparison Script
# Runs the same test scenarios against both Rust and Elixir backends
# and generates a comprehensive comparison report

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test scenarios to run
SCENARIOS=("baseline" "load_test" "stress_test")
TEST_TYPES=("api" "websocket")
BACKENDS=("rust" "elixir")

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
COMPARISON_DIR="comparisons/comparison_${TIMESTAMP}"

echo -e "${PURPLE}============================================${NC}"
echo -e "${PURPLE}    Backend Performance Comparison        ${NC}"
echo -e "${PURPLE}============================================${NC}"
echo ""

# Create comparison directory
mkdir -p "$COMPARISON_DIR"

echo -e "${BLUE}This will run comprehensive tests on both backends:${NC}"
echo -e "  Scenarios: ${SCENARIOS[*]}"
echo -e "  Test Types: ${TEST_TYPES[*]}"
echo -e "  Backends: ${BACKENDS[*]}"
echo -e "  Total Tests: $((${#SCENARIOS[@]} * ${#TEST_TYPES[@]} * ${#BACKENDS[@]}))"
echo ""

# Estimate time
total_tests=$((${#SCENARIOS[@]} * ${#TEST_TYPES[@]} * ${#BACKENDS[@]}))
estimated_minutes=$((total_tests * 8)) # ~8 minutes per test on average
echo -e "${YELLOW}Estimated completion time: ~${estimated_minutes} minutes${NC}"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Comparison cancelled."
    exit 1
fi

# Ensure test environment is up
echo -e "${YELLOW}Ensuring test environment is ready...${NC}"
docker-compose -f docker-compose.test.yml up -d

# Wait for all services to be healthy
echo -e "${YELLOW}Waiting for all services to be healthy...${NC}"
sleep 45

# Function to wait for backend health
wait_for_backend() {
    local backend=$1
    local timeout=60
    local counter=0
    
    if [ "${backend}" = "rust" ]; then
        health_url="http://localhost:8000/health"
    elif [ "${backend}" = "elixir" ]; then
        health_url="http://localhost:4000/health"
    fi
    
    echo -e "${YELLOW}Waiting for ${backend} backend...${NC}"
    while [ $counter -lt $timeout ]; do
        if curl -f -s "$health_url" > /dev/null 2>&1; then
            echo -e "${GREEN}${backend} backend is ready${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        counter=$((counter + 2))
    done
    
    echo -e "${RED}Timeout waiting for ${backend} backend${NC}"
    return 1
}

# Verify both backends are healthy
for backend in "${BACKENDS[@]}"; do
    if ! wait_for_backend "$backend"; then
        echo -e "${RED}Failed to verify ${backend} backend health${NC}"
        exit 1
    fi
done

echo -e "${GREEN}All backends are healthy, starting tests...${NC}"
echo ""

# Run all test combinations
test_count=0
total_tests=$((${#SCENARIOS[@]} * ${#TEST_TYPES[@]} * ${#BACKENDS[@]}))

for scenario in "${SCENARIOS[@]}"; do
    for test_type in "${TEST_TYPES[@]}"; do
        for backend in "${BACKENDS[@]}"; do
            test_count=$((test_count + 1))
            
            echo -e "${BLUE}============================================${NC}"
            echo -e "${BLUE}Test ${test_count}/${total_tests}: ${backend} ${scenario} ${test_type}${NC}"
            echo -e "${BLUE}============================================${NC}"
            
            # Run the test
            if ./stress-tests/run-tests.sh "$backend" "$scenario" "$test_type"; then
                echo -e "${GREEN}✓ Test completed successfully${NC}"
            else
                echo -e "${RED}✗ Test failed${NC}"
                # Continue with other tests even if one fails
            fi
            
            echo ""
            echo -e "${YELLOW}Waiting 30 seconds before next test...${NC}"
            sleep 30
        done
    done
done

echo -e "${PURPLE}============================================${NC}"
echo -e "${PURPLE}    Generating Comparison Report           ${NC}"
echo -e "${PURPLE}============================================${NC}"

# Generate comprehensive comparison report
cat > "${COMPARISON_DIR}/COMPARISON_REPORT.md" << 'EOF'
# Backend Performance Comparison Report

## Executive Summary

This report compares the performance characteristics of the Rust and Elixir backends for the location sharing application under various load conditions.

## Test Configuration

- **Timestamp**: TIMESTAMP_PLACEHOLDER
- **Scenarios Tested**: 
  - **Baseline**: 10 users, 2 minutes
  - **Load Test**: 100 users, 5 minutes  
  - **Stress Test**: 1000 users, 10 minutes
- **Test Types**: API Load Testing, WebSocket Stress Testing
- **Backends**: Rust (Axum/Tokio), Elixir (Phoenix/OTP)

## Key Metrics Evaluated

### Response Time Metrics
- **P95 Response Time**: 95th percentile response time
- **P99 Response Time**: 99th percentile response time
- **Average Response Time**: Mean response time
- **WebSocket Connection Time**: Time to establish WebSocket connection

### Throughput Metrics
- **Requests per Second**: API request handling capacity
- **WebSocket Messages per Second**: Real-time message processing capacity
- **Concurrent WebSocket Connections**: Maximum stable connections

### Reliability Metrics
- **Error Rate**: Percentage of failed requests
- **Connection Success Rate**: WebSocket connection success rate
- **Message Delivery Success Rate**: Real-time message delivery reliability

### Resource Utilization
- **CPU Usage**: Processor utilization under load
- **Memory Usage**: RAM consumption patterns
- **Network I/O**: Network bandwidth utilization
- **Database Connections**: PostgreSQL connection pooling efficiency

## Detailed Results

### API Load Testing Results

#### Baseline Test (10 users, 2 minutes)
- **Rust Backend**:
  - P95 Response Time: _See Grafana Dashboard_
  - P99 Response Time: _See Grafana Dashboard_
  - Error Rate: _See Grafana Dashboard_
  - CPU Usage: _See Prometheus Metrics_

- **Elixir Backend**:
  - P95 Response Time: _See Grafana Dashboard_
  - P99 Response Time: _See Grafana Dashboard_
  - Error Rate: _See Grafana Dashboard_
  - CPU Usage: _See Prometheus Metrics_

#### Load Test (100 users, 5 minutes)
- **Rust Backend**: _Results in Grafana_
- **Elixir Backend**: _Results in Grafana_

#### Stress Test (1000 users, 10 minutes)
- **Rust Backend**: _Results in Grafana_
- **Elixir Backend**: _Results in Grafana_

### WebSocket Stress Testing Results

#### Connection Storm Test
- **Maximum Concurrent Connections**:
  - Rust: _See results files_
  - Elixir: _See results files_

#### Location Update Flood Test
- **Messages per Second Capacity**:
  - Rust: _See results files_
  - Elixir: _See results files_

## Analysis and Observations

### Performance Characteristics

#### Rust Backend (Axum/Tokio)
**Strengths:**
- Low-level control over resource allocation
- Minimal runtime overhead
- Predictable memory usage patterns
- Excellent single-threaded performance

**Considerations:**
- Manual memory management complexity
- Steeper learning curve for developers
- Compile-time optimizations vs. runtime flexibility

#### Elixir Backend (Phoenix/OTP)
**Strengths:**
- Built-in fault tolerance (OTP supervision trees)
- Actor model for concurrent processing
- Hot code reloading capabilities
- Excellent for real-time applications

**Considerations:**
- Higher memory overhead per process
- Garbage collection pauses
- Learning curve for functional programming paradigms

### Scalability Patterns

#### Horizontal Scaling
- **Rust**: Stateless microservices, easy to containerize and replicate
- **Elixir**: Distributed Erlang nodes, built-in clustering capabilities

#### Vertical Scaling
- **Rust**: Efficient CPU and memory utilization
- **Elixir**: BEAM VM optimized for massive concurrency

## Recommendations

### For MVP Deployment
Based on the test results, consider the following factors:

1. **Performance Requirements**
   - If sub-millisecond latency is critical: Consider Rust
   - If handling massive concurrent users: Consider Elixir

2. **Development Team Expertise**
   - Rust systems programming experience
   - Elixir/Erlang functional programming background

3. **Operational Considerations**
   - Monitoring and debugging preferences
   - Deployment and scaling strategies

### Production Deployment Strategy

1. **Load Balancer Configuration**
   - Use nginx or HAProxy for traffic distribution
   - Configure health checks for both backends

2. **Database Optimization**
   - Connection pooling settings based on backend choice
   - Read replica configuration for scaling

3. **Monitoring Setup**
   - Prometheus metrics collection
   - Grafana dashboards for real-time monitoring
   - Alert rules for performance degradation

## Monitoring URLs

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)

## Test Data Location

Individual test results are stored in the `results/` directory with timestamps.
Raw K6 output files (JSON/CSV) are available for detailed analysis.

## Next Steps

1. **Review Grafana dashboards** for visual performance comparison
2. **Analyze Prometheus metrics** for resource utilization patterns
3. **Consider hybrid approach** using both backends for different use cases
4. **Run extended duration tests** (24+ hours) for stability assessment
5. **Test auto-scaling behavior** under varying load conditions

---

*Report generated automatically by the stress testing framework*
*For questions about this report, refer to the stress testing documentation*
EOF

# Replace timestamp placeholder
sed -i "s/TIMESTAMP_PLACEHOLDER/${TIMESTAMP}/g" "${COMPARISON_DIR}/COMPARISON_REPORT.md"

# Create results index
echo -e "${BLUE}Creating results index...${NC}"
cat > "${COMPARISON_DIR}/results-index.md" << EOF
# Test Results Index

## Generated: ${TIMESTAMP}

## Individual Test Results

EOF

# Find all result directories and add to index
find results/ -name "*_${TIMESTAMP:0:8}_*" -type d | sort | while read -r dir; do
    basename_dir=$(basename "$dir")
    echo "- [\`${basename_dir}\`](../${dir}/)" >> "${COMPARISON_DIR}/results-index.md"
done

# Copy aggregated data
echo -e "${BLUE}Copying test artifacts...${NC}"
cp -r results/ "${COMPARISON_DIR}/individual_results/" 2>/dev/null || echo "No individual results to copy"

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}    Comparison Complete!                   ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}Comparison report generated:${NC}"
echo -e "  📊 ${COMPARISON_DIR}/COMPARISON_REPORT.md"
echo -e "  📋 ${COMPARISON_DIR}/results-index.md"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review the comparison report"
echo -e "  2. Check Grafana dashboards: http://localhost:3000"
echo -e "  3. Analyze Prometheus metrics: http://localhost:9090"
echo -e "  4. Review individual test results in the results/ directory"
echo ""
echo -e "${YELLOW}To view the report:${NC}"
echo -e "  cat '${COMPARISON_DIR}/COMPARISON_REPORT.md'"