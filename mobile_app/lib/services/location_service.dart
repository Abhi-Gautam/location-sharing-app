import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';
import '../models/location.dart' as app_location;

/// Service for handling GPS location tracking
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  StreamController<app_location.Location>? _locationController;
  
  app_location.Location? _lastKnownLocation;
  bool _isTracking = false;
  
  /// Stream of location updates
  Stream<app_location.Location> get locationStream => 
      _locationController?.stream ?? const Stream.empty();

  /// Check if location tracking is active
  bool get isTracking => _isTracking;

  /// Get last known location
  app_location.Location? get lastKnownLocation => _lastKnownLocation;

  /// Check location permission status
  Future<LocationPermissionStatus> checkPermission() async {
    final permission = await Permission.location.status;
    
    switch (permission) {
      case PermissionStatus.granted:
        return LocationPermissionStatus.granted;
      case PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return LocationPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return LocationPermissionStatus.restricted;
      default:
        return LocationPermissionStatus.denied;
    }
  }

  /// Request location permission
  Future<LocationPermissionStatus> requestPermission() async {
    final permission = await Permission.location.request();
    
    switch (permission) {
      case PermissionStatus.granted:
        return LocationPermissionStatus.granted;
      case PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return LocationPermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return LocationPermissionStatus.restricted;
      default:
        return LocationPermissionStatus.denied;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location (one-time)
  Future<app_location.Location> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      // Check permissions
      final permissionStatus = await checkPermission();
      if (permissionStatus != LocationPermissionStatus.granted) {
        throw LocationException(
          LocationErrorCode.permissionDenied,
          'Location permission not granted',
        );
      }

      // Check if location services are enabled
      if (!await isLocationServiceEnabled()) {
        throw LocationException(
          LocationErrorCode.serviceDisabled,
          'Location services are disabled',
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );

      final location = _positionToLocation(position);
      _lastKnownLocation = location;
      
      return location;
    } on TimeoutException {
      throw LocationException(
        LocationErrorCode.timeout,
        'Location request timed out',
      );
    } on LocationServiceDisabledException {
      throw LocationException(
        LocationErrorCode.serviceDisabled,
        'Location services are disabled',
      );
    } on PermissionDeniedException {
      throw LocationException(
        LocationErrorCode.permissionDenied,
        'Location permission denied',
      );
    } catch (e) {
      throw LocationException(
        LocationErrorCode.unknown,
        'Failed to get location: $e',
      );
    }
  }

  /// Start location tracking
  Future<void> startTracking({
    Duration interval = AppConstants.locationUpdateInterval,
    double distanceFilter = 5.0, // meters
  }) async {
    if (_isTracking) return;

    try {
      // Check permissions
      final permissionStatus = await checkPermission();
      if (permissionStatus != LocationPermissionStatus.granted) {
        throw LocationException(
          LocationErrorCode.permissionDenied,
          'Location permission not granted',
        );
      }

      // Check if location services are enabled
      if (!await isLocationServiceEnabled()) {
        throw LocationException(
          LocationErrorCode.serviceDisabled,
          'Location services are disabled',
        );
      }

      // Initialize stream controller if needed
      _locationController ??= StreamController<app_location.Location>.broadcast();

      // Configure location settings
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // meters
      );

      // Start position stream
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          final location = _positionToLocation(position);
          _lastKnownLocation = location;
          
          // Only emit if accuracy is acceptable
          if (location.accuracy <= AppConstants.locationAccuracyThreshold) {
            _locationController?.add(location);
          }
        },
        onError: (error) {
          _locationController?.addError(LocationException(
            LocationErrorCode.unknown,
            'Location stream error: $error',
          ));
        },
      );

      _isTracking = true;
      print('Location tracking started');
    } catch (e) {
      rethrow;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    
    print('Location tracking stopped');
  }

  /// Convert Geolocator Position to app Location
  app_location.Location _positionToLocation(Position position) {
    return app_location.Location(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp ?? DateTime.now(),
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
    );
  }

  /// Calculate distance between two locations
  double calculateDistance(
    app_location.Location from,
    app_location.Location to,
  ) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Check if location is valid
  bool isValidLocation(app_location.Location location) {
    return location.latitude >= -90 &&
           location.latitude <= 90 &&
           location.longitude >= -180 &&
           location.longitude <= 180 &&
           location.accuracy <= AppConstants.locationAccuracyThreshold;
  }

  /// Get location accuracy description
  String getAccuracyDescription(double accuracy) {
    if (accuracy <= 5) {
      return 'Excellent';
    } else if (accuracy <= 10) {
      return 'Good';
    } else if (accuracy <= 25) {
      return 'Fair';
    } else if (accuracy <= 50) {
      return 'Poor';
    } else {
      return 'Very Poor';
    }
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Dispose the service
  Future<void> dispose() async {
    await stopTracking();
    
    if (_locationController != null && !_locationController!.isClosed) {
      await _locationController!.close();
      _locationController = null;
    }
  }
}

/// Location permission status
enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Location error codes
enum LocationErrorCode {
  permissionDenied,
  serviceDisabled,
  timeout,
  unknown,
}

/// Location service exception
class LocationException implements Exception {
  final LocationErrorCode code;
  final String message;

  const LocationException(this.code, this.message);

  @override
  String toString() => 'LocationException(${code.name}): $message';

  /// Check if error is due to permission issues
  bool get isPermissionError => code == LocationErrorCode.permissionDenied;

  /// Check if error is due to disabled services
  bool get isServiceError => code == LocationErrorCode.serviceDisabled;

  /// Check if error is due to timeout
  bool get isTimeoutError => code == LocationErrorCode.timeout;

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (code) {
      case LocationErrorCode.permissionDenied:
        return 'Location permission is required to share your location with others.';
      case LocationErrorCode.serviceDisabled:
        return 'Please enable location services in your device settings.';
      case LocationErrorCode.timeout:
        return 'Unable to get your current location. Please try again.';
      case LocationErrorCode.unknown:
        return 'An error occurred while getting your location. Please try again.';
    }
  }

  /// Get suggested action for the error
  String get suggestedAction {
    switch (code) {
      case LocationErrorCode.permissionDenied:
        return 'Grant location permission in app settings';
      case LocationErrorCode.serviceDisabled:
        return 'Enable location services';
      case LocationErrorCode.timeout:
        return 'Try again or move to an area with better GPS signal';
      case LocationErrorCode.unknown:
        return 'Check your GPS settings and try again';
    }
  }
}

/// Location service state
class LocationServiceState {
  final bool isTracking;
  final app_location.Location? lastLocation;
  final LocationPermissionStatus permissionStatus;
  final bool isServiceEnabled;
  final LocationException? error;

  const LocationServiceState({
    this.isTracking = false,
    this.lastLocation,
    this.permissionStatus = LocationPermissionStatus.denied,
    this.isServiceEnabled = false,
    this.error,
  });

  LocationServiceState copyWith({
    bool? isTracking,
    app_location.Location? lastLocation,
    LocationPermissionStatus? permissionStatus,
    bool? isServiceEnabled,
    LocationException? error,
  }) {
    return LocationServiceState(
      isTracking: isTracking ?? this.isTracking,
      lastLocation: lastLocation ?? this.lastLocation,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      error: error ?? this.error,
    );
  }

  /// Check if location is available
  bool get isLocationAvailable => 
      permissionStatus == LocationPermissionStatus.granted &&
      isServiceEnabled;

  /// Check if there's an error
  bool get hasError => error != null;

  @override
  String toString() {
    return 'LocationServiceState('
        'tracking: $isTracking, '
        'permission: $permissionStatus, '
        'service: $isServiceEnabled, '
        'location: ${lastLocation != null}, '
        'error: $error'
        ')';
  }
}

/// Extension methods for LocationPermissionStatus
extension LocationPermissionStatusExtension on LocationPermissionStatus {
  /// Check if permission is granted
  bool get isGranted => this == LocationPermissionStatus.granted;

  /// Check if permission is denied but can be requested
  bool get canRequest => this == LocationPermissionStatus.denied;

  /// Check if permission is permanently denied
  bool get isPermanentlyDenied => this == LocationPermissionStatus.permanentlyDenied;

  /// Get user-friendly description
  String get description {
    switch (this) {
      case LocationPermissionStatus.granted:
        return 'Location permission granted';
      case LocationPermissionStatus.denied:
        return 'Location permission denied';
      case LocationPermissionStatus.permanentlyDenied:
        return 'Location permission permanently denied';
      case LocationPermissionStatus.restricted:
        return 'Location permission restricted';
    }
  }
}