# Development Guide

This guide covers the development workflow, architecture decisions, and best practices for the Location Sharing mobile app.

## Development Environment Setup

### Prerequisites
- Flutter 3.16.0+
- Dart 3.1.0+
- Android Studio or VS Code
- Xcode (for iOS development)
- Git

### IDE Setup

#### VS Code Extensions
- Flutter
- Dart
- Flutter Riverpod Snippets
- Error Lens
- GitLens

#### Android Studio Plugins
- Flutter
- Dart
- Riverpod Snippets

### Environment Configuration

1. **Copy environment files**:
   ```bash
   cp .env.example .env
   cp android/local.properties.example android/local.properties
   ```

2. **Configure Google Maps API Key**:
   - Get API key from Google Cloud Console
   - Enable Maps SDK for Android and iOS
   - Add key to both `.env` and `android/local.properties`

3. **Backend Configuration**:
   - Start your chosen backend (Elixir or Rust)
   - Update API URLs in `.env`
   - Test connectivity with `curl` commands

## Architecture Overview

### State Management (Riverpod)

The app uses Riverpod for state management with a provider-based architecture:

```dart
// Provider Definition
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(/* dependencies */);
});

// Usage in Widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    // Use state...
  }
}
```

#### Key Providers
- `sessionProvider`: Manages session lifecycle and state
- `locationProvider`: Handles GPS tracking and location updates
- `participantsProvider`: Tracks session participants
- `storageServiceProvider`: Local data persistence

### Service Layer

Services handle external communication and platform features:

#### API Service
```dart
class ApiService {
  Future<CreateSessionResponse> createSession(CreateSessionRequest request);
  Future<Session> getSession(String sessionId);
  Future<JoinSessionResponse> joinSession(String sessionId, JoinSessionRequest request);
  // ... other methods
}
```

#### WebSocket Service
```dart
class WebSocketService {
  Stream<WebSocketMessage> get messages;
  Future<void> connect({required String sessionId, required String userId, required String token});
  void sendLocationUpdate(Location location);
  // ... other methods
}
```

#### Location Service
```dart
class LocationService {
  Stream<Location> get locationStream;
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<Location> getCurrentLocation();
  // ... other methods
}
```

### Model Layer

Models represent data structures with serialization support:

```dart
class Session {
  final String id;
  final String? name;
  final DateTime createdAt;
  final DateTime expiresAt;
  // ... other fields

  // JSON serialization
  factory Session.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  // API serialization (different format)
  static Session fromApiMap(Map<String, dynamic> map);
  Map<String, dynamic> toApiMap();
}
```

## Development Workflow

### 1. Feature Development

1. **Create feature branch**:
   ```bash
   git checkout -b feature/new-feature-name
   ```

2. **Follow TDD approach**:
   - Write tests first
   - Implement minimum code to pass tests
   - Refactor and improve

3. **Update providers if needed**:
   - Add new state properties
   - Implement state transitions
   - Handle error cases

4. **Update UI components**:
   - Follow Material Design 3 guidelines
   - Ensure responsive design
   - Add proper loading and error states

### 2. Testing Strategy

#### Unit Tests
```bash
flutter test test/unit_test.dart
```

Test individual functions and classes:
- Utility functions
- Model serialization
- Business logic

#### Widget Tests
```bash
flutter test test/widget_test.dart
```

Test UI components:
- Widget rendering
- User interactions
- Navigation flows

#### Integration Tests
```bash
flutter test integration_test/
```

Test complete workflows:
- End-to-end user scenarios
- Backend integration
- Platform-specific features

### 3. Code Quality

#### Linting
The project uses Flutter's recommended lints:
```yaml
dev_dependencies:
  flutter_lints: ^3.0.0
```

Run linting:
```bash
flutter analyze
```

#### Code Formatting
```bash
dart format .
```

#### Static Analysis
```bash
dart analyze --fatal-infos
```

### 4. Build and Deploy

#### Debug Builds
```bash
# Android
flutter run --debug

# iOS
flutter run --debug --simulator
```

#### Release Builds
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Backend Integration

### API Endpoints

All API calls go through the `ApiService` class:

```dart
// Create session
final response = await apiService.createSession(CreateSessionRequest(
  name: 'My Session',
  expiresInMinutes: 1440,
));

// Join session
final joinResponse = await apiService.joinSession(sessionId, JoinSessionRequest(
  displayName: 'John Doe',
  avatarColor: '#FF5733',
));
```

### WebSocket Communication

WebSocket messages follow a standardized format:

```dart
{
  "type": "location_update",
  "data": {
    "lat": 37.7749,
    "lng": -122.4194,
    "accuracy": 5.0,
    "timestamp": "2023-01-01T00:00:00Z"
  }
}
```

Handle incoming messages:
```dart
webSocketService.messages.listen((message) {
  switch (message.type) {
    case 'location_update':
      // Handle location update
      break;
    case 'participant_joined':
      // Handle participant joined
      break;
    // ... other message types
  }
});
```

### Backend Switching

The app supports both Elixir and Rust backends:

```dart
// Configuration
static String get backendType => const String.fromEnvironment('BACKEND_TYPE');

// Backend-specific WebSocket URL formatting
String _buildWebSocketUrl() {
  if (AppConfig.backendType == 'rust') {
    return '${AppConfig.wsBaseUrl}?token=$_token';
  } else {
    // Elixir Phoenix channels format
    return '${AppConfig.wsBaseUrl}?token=$_token&session_id=$_sessionId';
  }
}
```

## Platform-Specific Features

### Android Configuration

#### Permissions
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

#### Google Maps
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}" />
```

### iOS Configuration

#### Permissions
```xml
<!-- Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to share your location...</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access...</string>
```

#### Background Modes
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
</array>
```

## Performance Optimization

### 1. Location Updates
- Configurable update intervals (default: 2 seconds)
- Distance-based filtering to reduce unnecessary updates
- Battery optimization for background tracking

### 2. Map Rendering
- Efficient marker updates using cached icons
- Debounced camera movements
- Memory management for large participant lists

### 3. State Management
- Immutable state objects
- Efficient provider dependencies
- Proper dispose patterns

### 4. Network Optimization
- Request batching where possible
- WebSocket connection reuse
- Retry logic with exponential backoff

## Debugging

### Flutter Inspector
Use Flutter Inspector in your IDE to:
- Examine widget tree
- Debug layout issues
- Profile performance

### Network Debugging
```dart
// Enable HTTP logging in debug mode
if (AppConfig.isDebugMode) {
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));
}
```

### Location Debugging
```dart
// Debug location accuracy
print('Location accuracy: ${location.accuracy}m');
print('Location age: ${DateTime.now().difference(location.timestamp)}');
```

### WebSocket Debugging
```dart
// Debug WebSocket messages
webSocketService.messages.listen((message) {
  print('Received: ${message.type} - ${message.data}');
});
```

## Common Issues and Solutions

### 1. Location Issues
**Problem**: Location not updating
**Solutions**:
- Check location permissions
- Verify GPS is enabled
- Ensure location services are running
- Check for battery optimization restrictions

### 2. Map Issues
**Problem**: Map not loading
**Solutions**:
- Verify Google Maps API key
- Check internet connectivity
- Ensure Maps SDK is enabled in Google Cloud Console
- Check for CORS issues in web builds

### 3. WebSocket Issues
**Problem**: Connection dropping
**Solutions**:
- Implement proper reconnection logic
- Check network stability
- Verify WebSocket URL format
- Handle background app states

### 4. Backend Issues
**Problem**: API calls failing
**Solutions**:
- Check backend server status
- Verify API endpoint URLs
- Check request/response formats
- Implement proper error handling

## Code Style Guidelines

### 1. Naming Conventions
- Classes: `PascalCase`
- Variables/Functions: `camelCase`
- Constants: `camelCase` with `static const`
- Files: `snake_case`
- Providers: end with `Provider`

### 2. File Organization
- Group related functionality
- Use barrel exports for public APIs
- Keep files focused and small
- Follow Flutter project structure

### 3. Documentation
- Document public APIs
- Add inline comments for complex logic
- Keep README files updated
- Use dartdoc format for documentation

### 4. Error Handling
- Use custom exception classes
- Provide user-friendly error messages
- Log errors appropriately
- Implement graceful fallbacks

## Future Enhancements

### Planned Features
- QR code scanning for session joining
- Offline mode support
- Push notifications
- Session history and analytics
- Multiple map providers
- Voice commands

### Technical Improvements
- Code generation for models
- Better error boundary handling
- Performance monitoring
- Automated testing pipeline
- CI/CD setup

## Contributing

### Pull Request Process
1. Create feature branch
2. Add tests for new functionality
3. Update documentation
4. Run all tests and linting
5. Submit PR with clear description

### Code Review Checklist
- [ ] Tests pass
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No breaking changes
- [ ] Performance impact considered
- [ ] Security implications reviewed