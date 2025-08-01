# Troubleshooting Guide

Common issues and solutions for the Location Sharing application.

## 🚨 Quick Diagnosis

### Check System Status
```bash
# Check what's running
./run.sh --status

# Run health checks
./run.sh --health

# Test the system
./run.sh --test
```

## 🔧 Common Issues

### 1. Services Won't Start

#### Backend (Elixir) Issues

**Issue**: `mix phx.server` fails to start
```bash
# Check PostgreSQL is running
./run.sh --status

# Reset database if corrupted
cd backend_elixir
mix ecto.reset

# Check for port conflicts
lsof -i :4000
```

**Issue**: Database connection errors
```bash
# Ensure PostgreSQL is running
docker ps | grep postgres

# Restart database
cd backend_elixir
docker-compose down
docker-compose up -d postgres

# Check connection
mix ecto.migrate
```

**Issue**: Dependency compilation errors
```bash
cd backend_elixir
rm -rf _build deps
mix deps.get
mix deps.compile
```

#### Frontend (Flutter) Issues

**Issue**: Flutter won't start on port 52778
```bash
# Check for port conflicts
lsof -i :52778

# Kill existing Flutter processes
pkill -f "flutter.*52778"

# Restart Flutter
./run.sh --flutter
```

**Issue**: Google Maps not loading
1. Check your `.env` file has `GOOGLE_MAPS_API_KEY`
2. Verify the API key is valid
3. Ensure Maps JavaScript API is enabled in Google Cloud Console

**Issue**: Flutter compilation errors
```bash
cd mobile_app
flutter clean
flutter pub get
flutter pub upgrade
```

### 2. Real-time Features Not Working

#### WebSocket Connection Issues

**Issue**: Location updates not appearing on map

**Debug Steps**:
1. Check browser console for WebSocket errors
2. Verify backend is receiving WebSocket connections
3. Test with API participants

```bash
# 1. Create test session with API participants
./run.sh --test

# 2. Start location simulator
cd testing
node location-simulator.js session-data-basic.json

# 3. Join session manually and check map
```

**Issue**: "Still not seeing other users on map"

**Typical Causes**:
- WebSocket message format mismatch
- Location updates not being broadcast
- Map markers not being created

**Solutions**:
```bash
# Check Phoenix Channel logs
cd backend_elixir
tail -f elixir_server.log

# Check Flutter console for errors
# Open browser dev tools while on map screen

# Verify API participants are connected
cd testing
node location-simulator.js session-data-basic.json
# Look for "✅ joined location channel" messages
```

#### Location Simulator Issues

**Issue**: Location simulator shows "session_ended"
```bash
# Create fresh sessions
./run.sh --test

# Use the new session ID immediately
# Sessions are only active for testing duration
```

**Issue**: Location simulator WebSocket authentication fails
- Check that session was created via API (not manually)
- Verify WebSocket tokens are valid
- Ensure session hasn't expired

### 3. Testing Issues

#### API Testing Failures

**Issue**: `./run.sh --test` fails with "Backend not running"
```bash
# Start backend first
./run.sh --elixir

# Then run tests
./run.sh --test
```

**Issue**: Session creation fails
```bash
# Check backend health
curl http://localhost:4000/health

# Check database connectivity
cd backend_elixir
mix ecto.migrate

# Reset if needed
mix ecto.reset
```

#### Backend Tests Failing
```bash
cd backend_elixir

# Run with verbose output
mix test --trace

# Run specific failing test
mix test test/path/to/failing_test.exs

# Check test database
MIX_ENV=test mix ecto.reset
```

#### Frontend Tests Failing
```bash
cd mobile_app

# Clear Flutter cache
flutter clean
flutter pub get

# Run with verbose output
flutter test --reporter=verbose

# Run specific test
flutter test test/specific_test.dart
```

### 4. Performance Issues

#### High CPU Usage
- **UI Testing**: Stop UI testing if running (`./run.sh --stop`)
- **Multiple Processes**: Check for duplicate services (`./run.sh --status`)
- **Browser Instances**: Close unnecessary browser tabs

#### High Memory Usage
```bash
# Check running processes
ps aux | grep -E "(flutter|elixir|beam|node)"

# Stop all services and restart
./run.sh --stop
./run.sh --start
```

#### Slow Response Times
```bash
# Check database performance
cd backend_elixir
iex -S mix phx.server

# In IEx:
iex> :observer.start()  # Monitor system performance
```

### 5. Development Environment Issues

#### Docker Issues
```bash
# Check Docker is running
docker ps

# Restart PostgreSQL container
cd backend_elixir
docker-compose down
docker-compose up -d postgres

# Reset Docker environment
docker system prune -a
```

#### Environment Variables
```bash
# Check .env files exist
ls mobile_app/.env
ls backend_elixir/.env

# Verify environment is loaded
cd backend_elixir
mix phx.server
# Check logs for configuration values
```

#### Port Conflicts
```bash
# Check what's using ports
lsof -i :4000    # Backend
lsof -i :52778   # Frontend  
lsof -i :5432    # PostgreSQL
lsof -i :3001    # Dashboard (if running)

# Kill processes using ports
kill -9 $(lsof -ti:4000)
```

## 🔍 Debugging Tools

### Backend Debugging
```bash
cd backend_elixir

# Start with interactive shell
iex -S mix phx.server

# In IEx, inspect state:
iex> LocationSharing.Repo.all(LocationSharing.Sessions.Session)
iex> Phoenix.PubSub.subscribers(LocationSharing.PubSub, "session:abc123")
```

### Frontend Debugging
```bash
cd mobile_app

# Enable verbose logging
flutter run --verbose

# Run in debug mode (web)
flutter run -d chrome --web-renderer html
```

### Database Debugging
```bash
cd backend_elixir

# Connect to database directly
psql location_sharing_dev

-- Check sessions
SELECT * FROM sessions WHERE is_active = true;

-- Check participants  
SELECT s.name, p.display_name, p.last_seen 
FROM sessions s 
JOIN participants p ON s.id = p.session_id 
WHERE s.is_active = true;
```

### Network Debugging
```bash
# Test API endpoints
curl http://localhost:4000/health
curl -X POST http://localhost:4000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Session"}'

# Test WebSocket (using websocat if installed)
websocat ws://localhost:4000/socket/websocket?token=YOUR_JWT_TOKEN
```

## 📋 Error Reference

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "ECONNREFUSED localhost:4000" | Backend not running | `./run.sh --elixir` |
| "Port 52778 already in use" | Flutter already running | `pkill -f flutter.*52778` |
| "Database connection failed" | PostgreSQL not running | `docker-compose up -d postgres` |
| "Google Maps API key invalid" | Missing/invalid API key | Check `.env` file |
| "WebSocket connection failed" | Token/authentication issue | Rejoin session to get new token |
| "Session not found" | Expired/invalid session | Create new session |
| "mix test failed" | Test database issue | `MIX_ENV=test mix ecto.reset` |

### HTTP Status Codes

| Code | Meaning | Common Cause |
|------|---------|--------------|
| 404 | Not Found | Wrong URL or expired session |
| 422 | Unprocessable Entity | Invalid request data |
| 500 | Internal Server Error | Backend error, check logs |
| 503 | Service Unavailable | Backend not running |

### WebSocket Close Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 1000 | Normal Closure | Expected disconnection |
| 1002 | Protocol Error | Check message format |
| 1011 | Server Error | Check backend logs |
| 3000-3999 | Custom Application Errors | Check Phoenix Channel logs |

## 🚀 Recovery Procedures

### Full System Reset
```bash
# Stop everything
./run.sh --stop

# Reset database
cd backend_elixir
mix ecto.reset

# Clean Flutter
cd ../mobile_app
flutter clean
flutter pub get

# Restart everything
cd ..
./run.sh --start

# Verify everything works
./run.sh --test
```

### Reset Just Database
```bash
cd backend_elixir
mix ecto.reset
mix phx.server
```

### Reset Just Frontend
```bash
cd mobile_app
flutter clean
flutter pub get
cd ..
./run.sh --flutter
```

## 📞 Getting Help

### Log Locations
- **Backend logs**: `backend_elixir/elixir_server.log`
- **Frontend logs**: `mobile_app/flutter_server.log`
- **Browser console**: Open Developer Tools while using app

### Useful Commands for Support
```bash
# System information
./run.sh --status
./run.sh --health

# Version information
cd backend_elixir && mix --version
cd mobile_app && flutter --version
docker --version

# Process information
ps aux | grep -E "(beam|flutter|postgres)"
lsof -i :4000 -i :52778 -i :5432
```

### When to Escalate
1. **System consistently fails** after following troubleshooting steps
2. **Performance degradation** that affects usability
3. **Data corruption** or loss
4. **Security concerns** or unexpected behavior
5. **New error messages** not covered in this guide

---

**Remember**: Most issues can be resolved by:
1. Checking service status: `./run.sh --status`
2. Running health checks: `./run.sh --health`  
3. Restarting services: `./run.sh --stop && ./run.sh --start`
4. Running the test suite: `./run.sh --test`