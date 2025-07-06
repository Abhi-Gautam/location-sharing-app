# Comprehensive Stress Testing Suite

This directory contains a complete stress testing framework for the location-sharing application's dual backend architecture (Rust and Elixir).

## Overview

The testing suite provides comprehensive performance analysis capabilities including:

- **WebSocket Connection Testing**: Multi-session scenarios with realistic user behavior
- **Redis Pub/Sub Performance**: Cross-session message broadcasting and channel optimization
- **Multi-User Session Management**: Realistic join/leave patterns and session lifecycle testing
- **Backend Comparison**: Side-by-side performance analysis of Rust vs Elixir
- **Location Movement Simulation**: Realistic GPS movement patterns (walking, driving, stationary)

## Quick Start

### 1. Start the Test Environment
```bash
# From the project root
docker-compose -f docker-compose.test.yml up -d
```

### 2. Run Quick Tests
```bash
cd stress-tests

# Quick API test on Rust backend
./quick-test.sh rust api

# Quick WebSocket test on Elixir backend  
./quick-test.sh elixir websocket

# Quick backend comparison
./quick-test.sh both comparison
```

### 3. Run Comprehensive Test Suites
```bash
# All tests on both backends
./run-comprehensive-tests.sh all

# WebSocket tests only on Rust
./run-comprehensive-tests.sh websocket rust

# Redis pub/sub tests on Elixir
./run-comprehensive-tests.sh redis elixir

# Backend comparison suite
./run-comprehensive-tests.sh comparison
```

## Test Scripts

### Core Test Scripts (`k6/scripts/`)

1. **`api-load-test.js`** - REST API performance testing
   - Session creation, joining, participant management
   - Database query performance under load
   - HTTP request/response patterns

2. **`websocket-test.js`** - Basic WebSocket connection testing
   - Connection establishment and stability
   - Message send/receive performance
   - Location update frequency testing

3. **`multi-session-websocket-test.js`** - Advanced multi-session testing
   - Multiple concurrent sessions per virtual user
   - Cross-session message broadcasting
   - Realistic user behavior patterns
   - Geographic distribution simulation

4. **`redis-pubsub-test.js`** - Redis performance focus
   - Channel distribution patterns (high density, wide distribution, mixed)
   - Pub/sub latency measurement
   - Message delivery efficiency
   - Redis memory usage patterns

5. **`session-lifecycle-test.js`** - Session management testing
   - User behavior patterns (quick visitor, regular user, lurker, session hopper)
   - Session creation/join/leave cycles
   - Database connection pool stress
   - Participant turnover rates

6. **`backend-comparison-test.js`** - Side-by-side backend analysis
   - Identical operations on both backends
   - Performance metric comparison
   - Resource utilization analysis
   - Tagged metrics for easy comparison

## Test Scenarios (`k6/config/test-scenarios.json`)

### Basic Load Testing
- **baseline**: 10 users, 2 minutes (quick verification)
- **load_test**: 100 users, 5 minutes (normal load)
- **stress_test**: 1000 users, 10 minutes (find limits)
- **spike_test**: 500 users, 10-second ramp (traffic spikes)

### WebSocket Focused
- **websocket_connection_storm**: 5000 concurrent connections
- **location_update_flood**: High-frequency location updates
- **multi_session_load**: Multiple sessions with concurrent users

### Specialized Testing
- **redis_stress_test**: Redis pub/sub performance focus
- **session_lifecycle_stress**: User behavior pattern simulation
- **backend_comparison**: Side-by-side backend testing

## Key Features

### 1. Multi-Session Testing
- Each virtual user can participate in multiple sessions simultaneously
- Tests Redis channel scaling (many channels vs many users per channel)
- Simulates realistic user behavior where people join multiple groups

### 2. Realistic Movement Patterns
- **Walking**: 5 km/h with GPS variance
- **Driving**: 30 km/h with route changes  
- **Stationary**: GPS drift simulation
- **Geographic Distribution**: Tests across multiple cities

### 3. User Behavior Simulation
- **Quick Visitor**: 30-second sessions, low activity
- **Regular User**: 5-minute sessions, high activity
- **Lurker**: 10-minute sessions, minimal activity
- **Session Hopper**: Multiple sessions, medium activity

### 4. Redis Performance Analysis
- **Channel Distribution Testing**: 
  - High density: 100 users in 10 channels
  - Wide distribution: 2 users in 500 channels
  - Mixed pattern: 20 users in 50 channels
- **Message Burst Patterns**: Steady, bursty, spike patterns
- **Pub/Sub Latency Tracking**: End-to-end message delivery time

### 5. Backend Comparison Framework
- Tagged metrics for easy comparison (`backend="rust"` vs `backend="elixir"`)
- Identical test operations on both backends
- Resource utilization comparison
- Performance characteristic analysis

## Monitoring and Analysis

### Prometheus Metrics
Access at http://localhost:9090

Key metric categories:
- **Connection Metrics**: `websocket_connection_*`, `participant_joins`
- **Performance Metrics**: `backend_response_time`, `redis_channel_latency`
- **Throughput Metrics**: `location_updates_sent`, `redis_messages_per_second`
- **Reliability Metrics**: `websocket_connection_stability`, `session_*_success`

### Grafana Dashboards
Access at http://localhost:3000 (admin/admin123)

Recommended dashboard views:
- System resource utilization (CPU, Memory, Network)
- Backend performance comparison
- Redis pub/sub performance
- WebSocket connection patterns
- Database query performance

## Test Results

Results are stored in `results/` directory with structure:
```
results/
├── [backend]_[scenario]_[test_type]_[timestamp]/
│   ├── results.json         # Detailed K6 results
│   ├── results.csv          # CSV format for analysis
│   └── test-summary.md      # Test configuration summary
└── comprehensive_report_[timestamp]/
    └── comprehensive-test-report.md
```

## Usage Examples

### Development Testing
```bash
# Quick verification during development
./quick-test.sh rust baseline

# Test WebSocket functionality
./quick-test.sh elixir websocket

# Compare both backends quickly
./quick-test.sh both comparison
```

### Performance Analysis
```bash
# Complete API performance testing
./run-comprehensive-tests.sh api both

# Focus on WebSocket performance
./run-comprehensive-tests.sh websocket rust

# Redis pub/sub analysis
./run-comprehensive-tests.sh redis elixir
```

### Backend Comparison
```bash
# Full comparison suite
./run-comprehensive-tests.sh comparison

# Individual component comparison
./run-comprehensive-tests.sh websocket both
./run-comprehensive-tests.sh api both
```

### Stress Testing
```bash
# Complete stress testing
./run-comprehensive-tests.sh all both

# Find breaking points
./run-tests.sh rust stress_test websocket
./run-tests.sh elixir websocket_connection_storm websocket
```

## Interpreting Results

### Key Performance Indicators

1. **Response Time**: p95 < 100ms for API calls
2. **WebSocket Latency**: p95 < 500ms for message delivery
3. **Redis Performance**: p95 < 100ms for pub/sub operations
4. **Connection Stability**: > 98% success rate
5. **Throughput**: Requests/messages per second

### Backend Comparison Criteria

1. **Latency Percentiles**: Compare p50, p95, p99 across backends
2. **Resource Efficiency**: CPU/Memory usage per connection
3. **Concurrency Handling**: Maximum concurrent connections
4. **Error Rates**: Failure percentages under load
5. **Redis Integration**: Pub/sub performance differences

### Scaling Insights

- **Connection Limits**: Maximum WebSocket connections per instance
- **Database Performance**: Query response time under load
- **Redis Bottlenecks**: Channel limits and memory usage
- **Memory Patterns**: Per-connection overhead
- **CPU Utilization**: Processing efficiency

## Architecture Testing Focus

This testing suite specifically addresses the key differentiators between Rust and Elixir for real-time location sharing:

### Rust Backend Testing
- **Concurrency Model**: Tokio async performance
- **Memory Safety**: Zero-copy operations
- **WebSocket Efficiency**: Connection handling
- **Redis Integration**: Low-level client performance

### Elixir Backend Testing  
- **Actor Model**: GenServer concurrency
- **Fault Tolerance**: OTP supervision trees
- **Phoenix Channels**: Built-in pub/sub
- **Hot Code Reloading**: Live system updates

### Comparison Points
- **Development Velocity**: Implementation complexity
- **Runtime Performance**: Throughput and latency
- **Operational Complexity**: Deployment and monitoring
- **Scalability Patterns**: Horizontal vs vertical scaling
- **Error Recovery**: System resilience

## Next Steps

After running tests:

1. **Analyze Results**: Review Grafana dashboards and result files
2. **Identify Bottlenecks**: CPU, Memory, Network, Database, Redis
3. **Optimize Configuration**: Connection pools, Redis settings, etc.
4. **Plan Deployment**: Choose backend and sizing based on results
5. **Set Monitoring**: Production alerting thresholds
6. **Capacity Planning**: Cost vs performance analysis

## Troubleshooting

### Common Issues

1. **Environment Not Starting**: Check Docker resources and logs
2. **Backend Not Ready**: Increase health check timeouts
3. **Network Issues**: Verify Docker network configuration
4. **Results Missing**: Check K6 script errors and permissions
5. **High Resource Usage**: Monitor Docker Desktop resources

### Debug Commands
```bash
# Check environment status
docker-compose -f ../docker-compose.test.yml ps

# View backend logs
docker-compose -f ../docker-compose.test.yml logs rust-api
docker-compose -f ../docker-compose.test.yml logs elixir

# Check network connectivity
docker run --rm --network="location-sharing_test_network" curlimages/curl curl -f http://rust-api:8000/health
```

This comprehensive testing framework provides deep insights into both backend performance characteristics, enabling data-driven decisions for production deployment.