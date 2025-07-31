# Visual Testing Framework

This comprehensive testing framework enables visual testing, load testing, and performance analysis for the location sharing application.

## Quick Start

### 1. Setup
```bash
# Install dependencies
cd testing/visual-tests
npm install

# Optional: Install K6 for load testing
# macOS: brew install k6
# Other: https://k6.io/docs/getting-started/installation/
```

### 2. Run Basic Visual Test
```bash
# Light test (10 users, 5 minutes)
./run-visual-tests.sh

# Medium test (50 users, 10 minutes) 
./run-visual-tests.sh --scenario medium

# Custom configuration
./run-visual-tests.sh --users 25 --duration 600 --sessions 2
```

### 3. Monitor with Dashboard
```bash
# Start dashboard and run tests
./run-visual-tests.sh --scenario stress

# Dashboard will be available at:
# http://localhost:3001 - Main control panel
# http://localhost:3001/map - Live location map
# http://localhost:3001/metrics - Performance metrics
```

## Testing Scenarios

### Light Load (Default)
- **Users**: 10 simulated users
- **Sessions**: 1 session
- **Duration**: 5 minutes
- **Purpose**: Basic functionality validation

```bash
./run-visual-tests.sh --scenario light
```

### Medium Load
- **Users**: 50 simulated users
- **Sessions**: 2 sessions
- **Duration**: 10 minutes
- **Purpose**: Performance under moderate load

```bash
./run-visual-tests.sh --scenario medium
```

### Stress Testing
- **Users**: 100 simulated users
- **Sessions**: 5 sessions
- **Duration**: 15 minutes
- **Purpose**: Find breaking points and bottlenecks

```bash
./run-visual-tests.sh --scenario stress
```

### Endurance Testing
- **Users**: 100 simulated users
- **Sessions**: 2 sessions
- **Duration**: 60 minutes
- **Purpose**: Memory leaks and long-term stability

```bash
./run-visual-tests.sh --scenario endurance
```

## Framework Components

### 1. Test Coordinator (`test-coordinator.js`)
Main orchestrator that:
- Spawns browser instances via Puppeteer
- Coordinates session creation and user joining
- Manages location movement simulation
- Collects performance metrics
- Generates comprehensive reports

### 2. Browser Manager (`browser-manager.js`)
Handles browser automation:
- Manages multiple Puppeteer browser instances
- Simulates Flutter app interactions
- Handles browser crashes and recovery
- Provides browser performance monitoring

### 3. Movement Simulator (`movement-simulator.js`)
Generates realistic GPS data:
- **Random Walk**: Unpredictable movement patterns
- **Route Following**: Predefined path simulation
- **Circular Movement**: Continuous loops
- **Commute Patterns**: Realistic start/travel/stop cycles
- **Stationary**: Small variations around fixed points

### 4. K6 Load Testing
WebSocket and API stress testing:
- **WebSocket Load** (`k6-scripts/websocket-load.js`): Phoenix channel capacity testing
- **Session Stress** (`k6-scripts/session-stress.js`): Database and API load testing
- Progressive load ramping: 10 → 50 → 100 → 500+ users

### 5. Visual Dashboard
Real-time monitoring interface:
- **Control Panel**: Start/stop tests, configure parameters
- **Live Map**: Real-time user location visualization  
- **Metrics Dashboard**: Performance graphs and statistics
- **Health Monitoring**: Service status indicators

## Advanced Usage

### Custom Movement Patterns
```javascript
// In movement-simulator.js
const customPattern = movementSimulator.generateMovementPattern({
  patternType: 'route',
  speedType: 'driving',
  bounds: MovementSimulator.createCityBounds('new_york'),
  duration: 600
});
```

### Browser Configuration
```bash
# Run with visible browsers (for debugging)
./run-visual-tests.sh --no-headless --users 5

# Skip dashboard (headless mode)
./run-visual-tests.sh --no-dashboard --scenario medium
```

### K6 Load Testing Only
```bash
cd testing/visual-tests

# WebSocket stress test
k6 run k6-scripts/websocket-load.js

# Session creation stress test
k6 run k6-scripts/session-stress.js
```

### Dashboard-Only Mode
```bash
# Start dashboard server independently
npm run dashboard

# Dashboard available at http://localhost:3001
```

## Performance Metrics

### Collected Metrics
- **Session Creation Time**: API response times for session creation
- **Participant Join Time**: Time to join sessions
- **WebSocket Latency**: Message round-trip times
- **Location Update Rate**: Updates per second
- **Browser Performance**: Memory usage, frame rates
- **Error Rates**: Connection failures, API errors

### Report Generation
Test reports are automatically generated in `testing/visual-tests/reports/`:
- **JSON Reports**: Machine-readable detailed metrics
- **Markdown Summaries**: Human-readable test summaries
- **K6 Results**: Load testing performance data

## Troubleshooting

### Common Issues

#### Services Not Running
```bash
# Ensure backend and frontend are started
cd ../../
./run.sh --start
```

#### Port Conflicts
```bash
# Check if ports are in use
lsof -i :3001  # Dashboard
lsof -i :4000  # Backend
lsof -i :52778 # Frontend
```

#### Browser Crashes
```bash
# Run with visible browsers to debug
./run-visual-tests.sh --no-headless --users 1
```

#### K6 Not Found
```bash
# Install K6
brew install k6  # macOS
# or follow: https://k6.io/docs/getting-started/installation/
```

### Debug Mode
```bash
# Enable verbose logging
DEBUG=* ./run-visual-tests.sh --scenario light

# Check individual components
node test-coordinator.js run --users 1 --duration 60
node dashboard/server.js
```

## Integration with Existing Tests

The visual testing framework integrates with the existing test runner:

```bash
# Run all tests including quick visual validation
./test-runner.sh

# The visual test runs as a non-critical validation step
# after backend, frontend, and integration tests
```

## Extending the Framework

### Adding New Movement Patterns
1. Edit `movement-simulator.js`
2. Add new pattern in `generateNextLocation()` method
3. Test with custom configuration

### Adding New Metrics
1. Update `test-coordinator.js` to collect new metrics
2. Modify dashboard to display new metrics
3. Update report generation

### Custom Test Scenarios
1. Create new scenario in `run-visual-tests.sh`
2. Define user count, duration, and session parameters
3. Add to help documentation

## Architecture Overview

```
Visual Testing Framework
├── Test Coordinator
│   ├── Browser Manager (Puppeteer)
│   ├── Movement Simulator (GPS patterns)
│   └── Metrics Collection
├── K6 Load Testing
│   ├── WebSocket stress tests
│   └── API stress tests  
├── Dashboard Server
│   ├── Real-time monitoring
│   ├── Test control interface
│   └── Live visualization
└── Report Generation
    ├── Performance metrics
    ├── Error analysis
    └── Recommendations
```

## Performance Expectations

### Light Load (10 users)
- CPU Usage: < 20%
- Memory Usage: < 500MB
- Response Times: < 200ms
- Success Rate: > 99%

### Medium Load (50 users)  
- CPU Usage: < 50%
- Memory Usage: < 1GB
- Response Times: < 500ms
- Success Rate: > 95%

### Stress Load (100+ users)
- CPU Usage: Variable
- Memory Usage: < 2GB
- Response Times: < 1000ms
- Success Rate: > 90%

## Contributing

1. Follow existing code patterns
2. Add tests for new features
3. Update documentation
4. Test with multiple scenarios

## Support

For questions or issues:
1. Check the troubleshooting section
2. Review generated logs in `reports/`
3. Run individual components for debugging
4. Check service health with `./run.sh --health`