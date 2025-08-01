# Location Sharing Mobile App

A real-time location sharing Flutter application that works with both Rust and Elixir backends. This app allows users to create or join location sharing sessions and view participants' locations on an interactive map in real-time.

## Features

- **Cross-platform Support**: Android and iOS compatible
- **Real-time Location Sharing**: GPS tracking with 2-second updates
- **Interactive Maps**: Google Maps with dynamic participant tracking
- **Session Management**: Create, join, and manage location sharing sessions
- **Configurable Backend**: Switch between Rust and Elixir backends
- **Modern UI**: Material Design 3 with smooth animations
- **Privacy-focused**: Location data is only shared during active sessions

## Architecture

### State Management
- **Riverpod**: Reactive state management with providers
- **Session Provider**: Manages session state and lifecycle
- **Location Provider**: Handles GPS tracking and location updates
- **Participants Provider**: Tracks all session participants

### Services
- **API Service**: REST API communication with error handling
- **WebSocket Service**: Real-time communication with auto-reconnection
- **Location Service**: GPS tracking with permission handling
- **Storage Service**: Local data persistence

### Models
- **Session**: Location sharing session data
- **Participant**: User participant information
- **Location**: GPS coordinates with timestamp and accuracy

## Prerequisites

### Flutter Environment
- Flutter 3.16.0 or higher
- Dart 3.1.0 or higher
- Android Studio or VS Code with Flutter extensions

### Platform Requirements
- **Android**: API level 21 (Android 5.0) or higher
- **iOS**: iOS 12.0 or higher
- **Google Maps API Key**: Required for map functionality

### Backend Services
Choose one of the following backends:
- **Elixir Backend**: Phoenix application (recommended)
- **Rust Backend**: Axum-based API server

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd mobile_app
flutter pub get
```

### 2. Configure Environment Variables

Copy the environment template:
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
```env
# Google Maps API Key (required)
GOOGLE_MAPS_API_KEY=your_api_key_here

# Backend Type ('elixir' or 'rust')
BACKEND_TYPE=elixir

# API URLs (adjust for your setup)
API_BASE_URL=http://localhost:4000/api
WS_BASE_URL=ws://localhost:4000/socket/websocket
```

### 3. Android Configuration

Copy Android local properties:
```bash
cp android/local.properties.example android/local.properties
```

Edit `android/local.properties`:
```properties
flutter.sdk=/path/to/your/flutter
GOOGLE_MAPS_API_KEY=your_api_key_here
```

### 4. iOS Configuration

For iOS, add your Google Maps API key to `ios/Runner/Info.plist`:
```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>your_api_key_here</string>
```

### 5. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Maps SDK for Android and iOS
4. Create credentials (API Key)
5. Restrict the key to your app's package name

## Running the App

### Development Mode

Start your backend service first (Elixir or Rust), then run:

```bash
# For Android emulator
flutter run --dart-define=BACKEND_TYPE=elixir \
           --dart-define=API_BASE_URL=http://10.0.2.2:4000/api \
           --dart-define=WS_BASE_URL=ws://10.0.2.2:4000/socket/websocket

# For iOS simulator
flutter run --dart-define=BACKEND_TYPE=elixir \
           --dart-define=API_BASE_URL=http://localhost:4000/api \
           --dart-define=WS_BASE_URL=ws://localhost:4000/socket/websocket

# For physical device (replace with your computer's IP)
flutter run --dart-define=BACKEND_TYPE=elixir \
           --dart-define=API_BASE_URL=http://192.168.1.100:4000/api \
           --dart-define=WS_BASE_URL=ws://192.168.1.100:4000/socket/websocket
```

### Build Variants

```bash
# Debug build
flutter build apk --debug

# Profile build  
flutter build apk --profile

# Release build
flutter build apk --release

# iOS builds
flutter build ios --debug
flutter build ios --release
```

## Backend Integration

### Elixir Backend (Default)
```dart
// Configure for Elixir Phoenix
BACKEND_TYPE=elixir
API_BASE_URL=http://localhost:4000/api
WS_BASE_URL=ws://localhost:4000/socket/websocket
```

### Rust Backend
```dart
// Configure for Rust Axum
BACKEND_TYPE=rust
API_BASE_URL=http://localhost:8080/api
WS_BASE_URL=ws://localhost:8081/ws
```

The app automatically adapts to the selected backend type, handling different API endpoints and WebSocket connection formats.

## Key Features Implementation

### Session Management
- Create sessions with custom names and durations
- Join sessions via ID or deep links
- Real-time participant tracking
- Session expiration handling

### Location Tracking
- Continuous GPS tracking with 2-second intervals
- Permission handling for location access
- Background location sharing (when permitted)
- Location accuracy indicators

### Real-time Communication
- WebSocket connections with auto-reconnection
- Real-time participant join/leave notifications
- Live location updates
- Connection status indicators

### Map Integration
- Google Maps with custom markers
- Participant avatars on map
- Real-time location updates
- Center on user or all participants
- Accuracy circles for location precision

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Widget Tests
```bash
flutter test test/widget_test.dart
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Main app widget with routing
├── config/
│   ├── app_config.dart       # Environment configuration
│   └── theme.dart           # App theme and styling
├── core/
│   ├── constants.dart        # App constants
│   ├── utils.dart           # Utility functions
│   └── extensions.dart      # Dart extensions
├── models/
│   ├── session.dart         # Session data models
│   ├── participant.dart     # Participant models
│   └── location.dart        # Location models
├── services/
│   ├── api_service.dart     # REST API service
│   ├── websocket_service.dart # WebSocket service
│   ├── location_service.dart  # GPS location service
│   └── storage_service.dart   # Local storage service
├── providers/
│   ├── session_provider.dart     # Session state management
│   ├── location_provider.dart    # Location state management
│   └── participants_provider.dart # Participants management
├── screens/
│   ├── home_screen.dart          # Home screen
│   ├── create_session_screen.dart # Session creation
│   ├── join_session_screen.dart   # Session joining
│   └── map_screen.dart           # Real-time map view
└── widgets/
    ├── map_widget.dart           # Google Maps component
    ├── participant_avatar.dart   # Participant avatar widget
    └── session_controls.dart     # Session control buttons
```

## Dependencies

### Core Dependencies
- `flutter_riverpod`: State management
- `dio`: HTTP client
- `web_socket_channel`: WebSocket communication
- `google_maps_flutter`: Maps integration
- `geolocator`: Location services
- `permission_handler`: Permission management
- `shared_preferences`: Local storage
- `uuid`: Unique identifier generation

### Development Dependencies
- `flutter_test`: Testing framework
- `mockito`: Mocking for tests
- `build_runner`: Code generation
- `riverpod_generator`: Provider code generation

## Configuration Options

### App Configuration (lib/config/app_config.dart)
- Backend type selection
- API base URLs
- Map configuration
- Location update intervals
- Session duration limits

### Platform-specific Configuration
- **Android**: `android/app/src/main/AndroidManifest.xml`
- **iOS**: `ios/Runner/Info.plist`
- Location permissions
- Background processing
- Deep link handling

## Troubleshooting

### Common Issues

1. **Location not working**
   - Check location permissions
   - Ensure GPS is enabled
   - Verify location services are available

2. **Map not loading**
   - Verify Google Maps API key
   - Check internet connection
   - Ensure Maps SDK is enabled

3. **Backend connection issues**
   - Verify backend server is running
   - Check API URLs in configuration
   - Ensure network connectivity

4. **WebSocket connection problems**
   - Check WebSocket URL format
   - Verify backend WebSocket server
   - Check firewall/proxy settings

### Debug Mode
Enable debug mode in `app_config.dart`:
```dart
static bool get isDebugMode => true;
```

This provides additional logging and debug information.

## Contributing

1. Follow Flutter coding conventions
2. Add tests for new features
3. Update documentation
4. Use conventional commit messages

## License

This project is part of the Location Sharing system implementation.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review backend documentation
3. Check Flutter and Dart documentation
4. Verify Google Maps setup

## Performance Considerations

- Location updates every 2 seconds (configurable)
- Efficient map marker updates
- Memory management for large participant lists
- Battery optimization for background tracking
- Network usage optimization

## Security Notes

- Location data is only shared during active sessions
- No permanent storage of location data
- Session-based authentication
- Secure WebSocket connections (WSS in production)
- Input validation and sanitization