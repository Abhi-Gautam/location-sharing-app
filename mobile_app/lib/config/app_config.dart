class AppConfig {
  // Backend Configuration  
  static const String apiBaseUrl = 'http://localhost:4000/api';
  static const String wsBaseUrl = 'ws://localhost:4000/socket';
  static const String baseUrl = 'http://localhost:4000/api';
  static const String wsUrl = 'ws://localhost:4000/socket';
  static const String environment = 'development';
  static const String backendType = 'elixir';
  
  // App Information
  static const String appName = 'Location Sharing';
  static const String appVersion = '1.0.0';
  static const bool isDebugMode = true;
  
  // Map Configuration
  static const double defaultMapZoom = 15.0;
  static const double minMapZoom = 3.0;
  static const double maxMapZoom = 20.0;
  
  // Session Configuration
  static const int maxParticipants = 50;
  static const int defaultSessionDurationMinutes = 1440;
  
  // Validation and Helper Methods
  static bool isValid() {
    return apiBaseUrl.isNotEmpty && wsBaseUrl.isNotEmpty;
  }
  
  static Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'appVersion': appVersion,
      'environment': environment,
      'backendType': backendType,
      'apiBaseUrl': apiBaseUrl,
      'wsBaseUrl': wsBaseUrl,
      'isDebugMode': isDebugMode,
      'defaultMapZoom': defaultMapZoom,
      'minMapZoom': minMapZoom,
      'maxMapZoom': maxMapZoom,
      'maxParticipants': maxParticipants,
      'defaultSessionDurationMinutes': defaultSessionDurationMinutes,
    };
  }
}
