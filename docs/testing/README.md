# Testing Guide

Comprehensive testing documentation for the Location Sharing application.

## 🚀 Quick Start

### Run All Tests
```bash
# Run complete test suite (recommended after any changes)
./run.sh --test
```

This includes:
- ✅ Backend tests (Elixir/Phoenix) - 40 tests
- ✅ Frontend unit tests (Flutter/Dart) - 18 tests  
- ✅ API-based testing with real sessions
- ✅ Service health checks
- ✅ Basic integration tests

## 📋 Testing Approaches

### 1. API-Based Testing (Recommended)

**Best for**: Regular testing, CI/CD, development workflow

```bash
# Create test sessions with API participants
./run.sh --test-api

# Or specify scenario
./run.sh --test-api small    # 1 session, 2 participants
./run.sh --test-api basic    # 2 sessions, 3 participants each
./run.sh --test-api stress   # 5 sessions, 8 participants each
```

**Benefits**:
- ✅ Fast execution (no browser instances)
- ✅ Reliable and deterministic
- ✅ Perfect for CI/CD pipelines
- ✅ Tests real backend functionality
- ✅ Low resource usage

### 2. Visual/UI Testing

**Best for**: Visual regression, end-to-end validation

```bash
# Run UI-based tests (resource intensive)
./run.sh --test-ui
```

**Warning**: Spawns multiple browser instances, high resource usage.

## 🧪 Test Categories

### Backend Tests (40 tests)
```bash
cd backend_elixir
mix test

# Specific test suites
mix test test/location_sharing_web/controllers/  # API controllers
mix test test/location_sharing_web/channels/     # WebSocket channels
mix test test/location_sharing/                  # Business logic
```

**Coverage**:
- ✅ REST API endpoints (sessions, participants, health)
- ✅ WebSocket channels (connection, authentication, real-time)
- ✅ Database operations (CRUD, validation, constraints)
- ✅ Error handling (invalid data, auth failures)

### Frontend Tests (18 tests)
```bash
cd mobile_app
flutter test

# Specific test files
flutter test test/unit_test.dart     # Core logic
flutter test test/widget_test.dart   # UI components (basic)
```

**Coverage**:
- ✅ Utility functions (colors, validation, distance calculation)
- ✅ Data models (Session, Participant, Location)
- ✅ Business logic (API mapping, status handling)

### Integration Tests
```bash
# Included in main test runner
./run.sh --test
```

**Coverage**:
- ✅ API session creation via REST
- ✅ Health monitoring across all services
- ✅ Service connectivity (backend, frontend, database)

## 📊 API-Based Testing Details

### Session Creation & Management
```bash
# The API testing creates real sessions you can join manually:
./run.sh --test

# Session IDs are displayed immediately:
# 📋 Session ID: cad1d2ee-6d37-460e-b982-7605816a5970
# 🔗 Quick Join: http://localhost:52778
```

### Location Simulation
```bash
# After creating sessions, simulate participant movement:
cd testing
node location-simulator.js session-data-basic.json

# This makes API participants move around on the map in real-time
```

### Testing Scenarios

| Scenario | Sessions | Participants | Use Case |
|----------|----------|--------------|----------|
| `small`  | 1        | 2            | Quick validation |
| `basic`  | 2        | 3 each       | Standard testing |
| `medium` | 3        | 5 each       | Load testing |
| `stress` | 5        | 8 each       | Stress testing |

## 🔧 Manual Testing Workflow

### 1. Start Services
```bash
./run.sh --start
```

### 2. Create Test Sessions
```bash
./run.sh --test
# Note the Session IDs displayed
```

### 3. Join Sessions Manually
1. Open `http://localhost:52778`
2. Click "Join Session"
3. Paste the Session ID from step 2
4. Enter your name and join

### 4. Simulate Participant Movement
```bash
cd testing
node location-simulator.js session-data-basic.json
```

### 5. Verify Real-time Updates
- Check that API participants appear on the map
- Verify they move around in real-time
- Test location updates, participant join/leave

## 🚨 Troubleshooting Tests

### Backend Test Failures
```bash
cd backend_elixir
mix test --trace              # Verbose output
mix test --seed 123           # Reproducible order
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
./run.sh --status            # Check running services
./run.sh --health            # Run health checks
```

### Common Issues

#### Backend Not Running
```bash
./run.sh --elixir            # Start Elixir backend only
# Then run tests
```

#### Flutter App Not Running
```bash
./run.sh --flutter           # Start Flutter app only
# Then run tests
```

#### Database Issues
```bash
cd backend_elixir
mix ecto.reset               # Reset database
mix ecto.setup               # Recreate and migrate
```

#### Port Conflicts
```bash
# Check if ports are in use
lsof -i :4000                # Backend
lsof -i :52778               # Frontend
lsof -i :5432                # PostgreSQL
```

## 📈 Test Development Guidelines

### Adding New Tests

1. **Backend (Elixir)**:
   ```elixir
   # test/location_sharing_web/controllers/my_controller_test.exs
   defmodule LocationSharingWeb.MyControllerTest do
     use LocationSharingWeb.ConnCase
     
     test "should do something", %{conn: conn} do
       # Your test here
     end
   end
   ```

2. **Frontend (Flutter)**:
   ```dart
   // test/my_feature_test.dart
   import 'package:flutter_test/flutter_test.dart';
   
   void main() {
     group('MyFeature', () {
       test('should do something', () {
         // Your test here
       });
     });
   }
   ```

### Test Best Practices

1. **Always run tests** before committing changes
2. **Write tests first** for new features (TDD)
3. **Keep tests fast** - current suite runs in ~10 seconds
4. **Test error cases** and edge conditions
5. **Use descriptive test names** that explain behavior
6. **Mock external dependencies** for reliability

## 🎯 Continuous Integration

### Recommended CI Workflow
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Services
        run: ./run.sh --setup
      - name: Run Tests
        run: ./run.sh --test
```

### Test Coverage Goals
- Backend: > 90% line coverage
- Frontend: > 80% line coverage
- Integration: All critical paths covered

## 📊 Performance Expectations

### Test Execution Times
- Backend tests: ~5 seconds
- Frontend tests: ~3 seconds
- API tests: ~10 seconds
- Full suite: ~15 seconds

### Resource Usage (API Testing)
- CPU: < 10%
- Memory: < 200MB
- Network: Minimal localhost traffic

### Resource Usage (Visual Testing)
- CPU: 50-80% (browser instances)
- Memory: 1-2GB
- Network: Higher due to multiple browser sessions

## 🔗 Related Documentation

- [API Reference](../backend/api-reference.md)
- [Architecture Overview](../architecture.md)
- [Development Guide](../development.md)
- [Troubleshooting](../troubleshooting.md)

---

**Key Points**:
1. Use `./run.sh --test` for regular testing
2. API-based testing is the recommended default
3. Always run tests after making changes
4. Visual testing is available but resource-intensive
5. Test coverage is comprehensive across all components