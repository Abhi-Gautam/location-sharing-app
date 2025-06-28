/// Application-wide constants
class AppConstants {
  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);

  // Network timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration websocketTimeout = Duration(seconds: 10);
  static const Duration websocketReconnectDelay = Duration(seconds: 5);

  // Location settings
  static const Duration locationUpdateInterval = Duration(seconds: 2);
  static const double locationAccuracyThreshold = 50.0; // meters
  static const Duration locationTimeout = Duration(seconds: 15);

  // Map settings
  static const double defaultLatitude = 37.7749; // San Francisco
  static const double defaultLongitude = -122.4194;
  static const double mapPaddingFactor = 0.1; // 10% padding around markers
  static const Duration mapAnimationDuration = Duration(milliseconds: 800);

  // UI settings
  static const double borderRadius = 12.0;
  static const double cardElevation = 1.0;
  static const double buttonHeight = 48.0;
  static const double avatarSize = 40.0;
  static const double markerSize = 60.0;

  // Validation
  static const int minDisplayNameLength = 2;
  static const int maxDisplayNameLength = 30;
  static const int minSessionNameLength = 1;
  static const int maxSessionNameLength = 50;

  // Storage keys
  static const String storageKeyUserId = 'user_id';
  static const String storageKeyDisplayName = 'display_name';
  static const String storageKeyAvatarColor = 'avatar_color';
  static const String storageKeyCurrentSession = 'current_session';
  static const String storageKeyBackendType = 'backend_type';

  // WebSocket message types
  static const String wsLocationUpdate = 'location_update';
  static const String wsParticipantJoined = 'participant_joined';
  static const String wsParticipantLeft = 'participant_left';
  static const String wsSessionEnded = 'session_ended';
  static const String wsPing = 'ping';
  static const String wsPong = 'pong';
  static const String wsError = 'error';

  // Error codes
  static const String errorInvalidSession = 'INVALID_SESSION';
  static const String errorSessionFull = 'SESSION_FULL';
  static const String errorPermissionDenied = 'PERMISSION_DENIED';
  static const String errorLocationUnavailable = 'LOCATION_UNAVAILABLE';
  static const String errorNetworkError = 'NETWORK_ERROR';
  static const String errorUnknown = 'UNKNOWN_ERROR';

  // Regular expressions
  static final RegExp sessionIdRegex = RegExp(r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$');
  static final RegExp colorRegex = RegExp(r'^#([A-Fa-f0-9]{6})$');

  // Default values
  static const String defaultAvatarColor = '#FF5733';
  static const int defaultSessionDuration = 1440; // 24 hours in minutes
  static const int maxRetryAttempts = 3;
}