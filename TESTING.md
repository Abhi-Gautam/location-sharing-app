# Testing Guide

This document describes the testing infrastructure for the Location Sharing application.

## Quick Start

### Run All Tests After Every Change
```bash
./test-runner.sh
```

This script runs:
- ✅ Backend tests (Elixir/Phoenix)
- ✅ Frontend unit tests (Flutter/Dart)  
- ✅ Service health checks
- ✅ Basic integration test

### Monitor Service Health
```bash
./health-monitor.sh
# or with custom interval
./health-monitor.sh --interval=60
```

## Individual Test Commands

### Backend Tests
```bash
cd backend_elixir
mix test                    # Run all tests
mix test --failed           # Run only failed tests
mix test test/path_to_test  # Run specific test file
```

### Frontend Tests
```bash
cd mobile_app
flutter test test/unit_test.dart    # Run unit tests
flutter test test/widget_test.dart  # Run widget tests (may have UI issues)
flutter test                        # Run all tests
```

### Service Management
```bash
./run.sh --start            # Start all services
./run.sh --stop             # Stop all services
./run.sh --health           # Check health
./run.sh --status           # Check status
```

## Test Coverage

### Backend Tests (40 tests)
- ✅ **API Controllers**: Session CRUD, Participant management, Health checks
- ✅ **WebSocket Channels**: Connection, authentication, location updates, ping/pong
- ✅ **Database Integration**: Factory patterns, data validation, constraints
- ✅ **Error Handling**: Invalid data, authentication failures, session states

### Frontend Tests (18 unit tests)
- ✅ **Utils**: Color generation, validation, distance calculation, initials
- ✅ **Models**: Session, Participant, Location serialization
- ✅ **Data Processing**: API mapping, bounds calculation, status logic

### Integration Tests
- ✅ **Basic API**: Session creation via REST endpoint
- ✅ **Health Monitoring**: All service health checks
- ✅ **Service Connectivity**: Backend, frontend, database availability

## Test Architecture

### Backend (Elixir/Phoenix)
- **ConnCase**: HTTP controller testing with database sandbox
- **ChannelCase**: WebSocket channel testing with authentication
- **DataCase**: Database operations with transaction rollback
- **Factory**: Test data generation with proper timestamps and associations

### Frontend (Flutter/Dart)  
- **Unit Tests**: Pure function testing without UI dependencies
- **Widget Tests**: UI component testing (basic implementation)
- **Model Tests**: Data serialization and business logic

### Scripts
- **test-runner.sh**: Comprehensive test suite for continuous integration
- **health-monitor.sh**: Real-time service monitoring for development

## Running Tests After Changes

Always run the test suite after making changes:

```bash
# After backend changes
./test-runner.sh

# After frontend changes  
./test-runner.sh

# After configuration changes
./test-runner.sh
```

## Debugging Test Failures

### Backend Test Failures
```bash
cd backend_elixir
mix test --trace              # Verbose output
mix test --seed 123           # Reproducible test order
mix test --max-failures 1     # Stop after first failure
```

### Frontend Test Failures
```bash
cd mobile_app
flutter test --reporter=verbose
flutter test --plain-name "specific test name"
```

### Service Issues
```bash
./run.sh --status            # Check what's running
./run.sh --health            # Run health checks
./health-monitor.sh          # Real-time monitoring
```

## Visual Testing Framework

### Comprehensive Multi-User Testing
The visual testing framework provides advanced capabilities for testing with multiple sessions, users, and realistic movement patterns:

```bash
# Quick validation
cd testing && ./validate-framework.sh

# Light test (10 users, 5 minutes)
cd testing/visual-tests && ./run-visual-tests.sh

# Stress test (100 users, 15 minutes)
./run-visual-tests.sh --scenario stress

# Custom configuration
./run-visual-tests.sh --users 50 --duration 600 --sessions 3
```

### Testing Scenarios Available
- **Light Load**: 10 users, 1 session, 5 minutes - Basic functionality validation
- **Medium Load**: 50 users, 2 sessions, 10 minutes - Performance under moderate load  
- **Stress Testing**: 100 users, 5 sessions, 15 minutes - Find breaking points
- **Endurance Testing**: 100 users, 2 sessions, 60 minutes - Long-term stability

### Real-time Dashboard
Visual monitoring and control interface:
- **Control Panel**: http://localhost:3001 - Start/stop tests, configure parameters
- **Live Map**: http://localhost:3001/map - Real-time user location visualization
- **Metrics**: http://localhost:3001/metrics - Performance graphs and statistics

### Movement Simulation
Realistic GPS patterns for comprehensive testing:
- **Random Walk**: Unpredictable movement patterns
- **Route Following**: Predefined path simulation  
- **Circular Movement**: Continuous loops around fixed points
- **Commute Patterns**: Realistic start/travel/stop cycles
- **Stationary**: Small variations around fixed locations

### Load Testing with K6
WebSocket and API stress testing:
- **WebSocket Load Testing**: Phoenix channel capacity testing
- **Session Stress Testing**: Database and API load testing
- **Progressive Load Ramping**: 10 → 50 → 100 → 500+ concurrent users

### Performance Metrics Collected
- Session creation and join times
- WebSocket message latency
- Location update rates
- Browser performance metrics
- Error rates and failure points

### Integration with Existing Tests
The visual testing framework integrates seamlessly:

```bash
# Regular test runner now includes quick visual validation
./test-runner.sh

# Dedicated visual testing
cd testing/visual-tests
./run-visual-tests.sh --scenario medium
```

## Next Steps

The comprehensive testing infrastructure is now complete with:

- ✅ **Unit & Integration Tests** - Backend (40 tests) + Frontend (18 tests)
- ✅ **Visual Testing Framework** - Multi-user browser automation
- ✅ **Load Testing** - K6 WebSocket and API stress testing  
- ✅ **Real-time Monitoring** - Web dashboard with live metrics
- ✅ **Movement Simulation** - Realistic GPS patterns
- ✅ **Performance Analysis** - Comprehensive metrics collection

Future enhancements could include:
- [ ] Visual regression testing for UI components
- [ ] API contract testing
- [ ] Cross-browser compatibility testing
- [ ] Mobile device testing simulation

## Test Development Guidelines

1. **Always run tests** before committing changes
2. **Write tests first** for new features (TDD approach)
3. **Keep tests fast** - current full suite runs in ~10 seconds
4. **Test error cases** as well as happy paths
5. **Use descriptive test names** that explain the behavior being tested
6. **Mock external dependencies** to ensure test reliability