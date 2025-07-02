import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../models/location.dart';
import '../models/session.dart';
import '../core/constants.dart';
import 'session_provider.dart';

/// Provider for location service
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Location state provider
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref.read(locationServiceProvider));
});

/// Location state
class LocationState {
  final Location? currentLocation;
  final LocationPermissionStatus permissionStatus;
  final bool isServiceEnabled;
  final bool isTracking;
  final LocationException? error;
  final bool isLoading;

  const LocationState({
    this.currentLocation,
    this.permissionStatus = LocationPermissionStatus.denied,
    this.isServiceEnabled = false,
    this.isTracking = false,
    this.error,
    this.isLoading = false,
  });

  LocationState copyWith({
    Location? currentLocation,
    LocationPermissionStatus? permissionStatus,
    bool? isServiceEnabled,
    bool? isTracking,
    LocationException? error,
    bool? isLoading,
  }) {
    return LocationState(
      currentLocation: currentLocation ?? this.currentLocation,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      isTracking: isTracking ?? this.isTracking,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Check if location is available
  bool get isLocationAvailable =>
      permissionStatus == LocationPermissionStatus.granted &&
      isServiceEnabled;

  /// Check if there's an error
  bool get hasError => error != null;

  /// Check if location data is valid
  bool get hasValidLocation => currentLocation != null;

  @override
  String toString() {
    return 'LocationState('
        'hasLocation: $hasValidLocation, '
        'permission: $permissionStatus, '
        'service: $isServiceEnabled, '
        'tracking: $isTracking, '
        'error: $error'
        ')';
  }
}

/// Location state notifier
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _locationService;
  StreamSubscription<Location>? _locationSubscription;
  Timer? _periodicLocationTimer;

  LocationNotifier(this._locationService) : super(const LocationState()) {
    _initialize();
  }

  /// Initialize location state
  Future<void> _initialize() async {
    await _checkPermissionAndService();
  }

  /// Check permission and service status
  Future<void> _checkPermissionAndService() async {
    try {
      state = state.copyWith(isLoading: true);

      final permissionStatus = await _locationService.checkPermission();
      final isServiceEnabled = await _locationService.isLocationServiceEnabled();

      state = state.copyWith(
        permissionStatus: permissionStatus,
        isServiceEnabled: isServiceEnabled,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: LocationException(LocationErrorCode.unknown, e.toString()),
      );
    }
  }

  /// Request location permission
  Future<bool> requestPermission() async {
    try {
      state = state.copyWith(isLoading: true);

      final permissionStatus = await _locationService.requestPermission();
      final isServiceEnabled = await _locationService.isLocationServiceEnabled();

      state = state.copyWith(
        permissionStatus: permissionStatus,
        isServiceEnabled: isServiceEnabled,
        isLoading: false,
        error: null,
      );

      return permissionStatus == LocationPermissionStatus.granted;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: LocationException(LocationErrorCode.unknown, e.toString()),
      );
      return false;
    }
  }

  /// Get current location (one-time)
  Future<Location?> getCurrentLocation() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final location = await _locationService.getCurrentLocation();
      
      state = state.copyWith(
        currentLocation: location,
        isLoading: false,
      );

      return location;
    } on LocationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: LocationException(LocationErrorCode.unknown, e.toString()),
      );
      return null;
    }
  }

  /// Start location tracking
  Future<bool> startTracking() async {
    if (state.isTracking) return true;

    try {
      state = state.copyWith(isLoading: true, error: null);

      // Check permissions first
      if (state.permissionStatus != LocationPermissionStatus.granted) {
        final granted = await requestPermission();
        if (!granted) {
          state = state.copyWith(
            isLoading: false,
            error: const LocationException(
              LocationErrorCode.permissionDenied,
              'Location permission is required',
            ),
          );
          return false;
        }
      }

      // Start location service tracking
      await _locationService.startTracking();

      // Listen to location updates
      _locationSubscription = _locationService.locationStream.listen(
        (location) {
          state = state.copyWith(currentLocation: location);
        },
        onError: (error) {
          state = state.copyWith(
            error: error is LocationException
                ? error
                : LocationException(LocationErrorCode.unknown, error.toString()),
          );
        },
      );

      state = state.copyWith(
        isTracking: true,
        isLoading: false,
      );

      return true;
    } on LocationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: LocationException(LocationErrorCode.unknown, e.toString()),
      );
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!state.isTracking) return;

    try {
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      await _locationService.stopTracking();

      _periodicLocationTimer?.cancel();
      _periodicLocationTimer = null;

      state = state.copyWith(
        isTracking: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: LocationException(LocationErrorCode.unknown, e.toString()),
      );
    }
  }

  /// Start periodic location updates for WebSocket
  void startPeriodicUpdates(Function(Location) onLocationUpdate) {
    if (_periodicLocationTimer != null) return;

    _periodicLocationTimer = Timer.periodic(
      AppConstants.locationUpdateInterval,
      (_) async {
        if (state.currentLocation != null && state.isTracking) {
          onLocationUpdate(state.currentLocation!);
        }
      },
    );
  }

  /// Stop periodic location updates
  void stopPeriodicUpdates() {
    _periodicLocationTimer?.cancel();
    _periodicLocationTimer = null;
  }

  /// Refresh location status
  Future<void> refresh() async {
    await _checkPermissionAndService();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _periodicLocationTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

/// Provider for location permission status
final locationPermissionProvider = FutureProvider<LocationPermissionStatus>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return locationService.checkPermission();
});

/// Provider for location service enabled status
final locationServiceEnabledProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return locationService.isLocationServiceEnabled();
});

/// Provider for current location (one-time fetch)
final currentLocationProvider = FutureProvider<Location?>((ref) async {
  final locationNotifier = ref.read(locationProvider.notifier);
  return locationNotifier.getCurrentLocation();
});

/// Provider that combines location state with session provider
final locationWithSessionProvider = Provider<LocationWithSession>((ref) {
  final locationState = ref.watch(locationProvider);
  final sessionState = ref.watch(sessionProvider);
  
  return LocationWithSession(
    locationState: locationState,
    sessionState: sessionState,
  );
});

/// Combined location and session state
class LocationWithSession {
  final LocationState locationState;
  final SessionState sessionState;

  const LocationWithSession({
    required this.locationState,
    required this.sessionState,
  });

  /// Check if we should start location tracking
  bool get shouldStartTracking =>
      sessionState.isInSession &&
      locationState.isLocationAvailable &&
      !locationState.isTracking;

  /// Check if we should stop location tracking
  bool get shouldStopTracking =>
      !sessionState.isInSession && locationState.isTracking;

  /// Check if location sharing is active
  bool get isLocationSharingActive =>
      sessionState.isInSession &&
      locationState.isTracking &&
      locationState.hasValidLocation;
}

/// Location tracking controller provider
final locationTrackingControllerProvider = Provider<LocationTrackingController>((ref) {
  return LocationTrackingController(
    ref.read(locationProvider.notifier),
    ref.read(sessionProvider.notifier),
  );
});

/// Location tracking controller
class LocationTrackingController {
  final LocationNotifier _locationNotifier;
  final SessionNotifier _sessionNotifier;

  LocationTrackingController(this._locationNotifier, this._sessionNotifier);

  /// Start location sharing for session
  Future<bool> startLocationSharing() async {
    final success = await _locationNotifier.startTracking();
    
    if (success) {
      // Start periodic updates to send to WebSocket
      _locationNotifier.startPeriodicUpdates((location) {
        _sessionNotifier.sendLocationUpdate(location);
        _sessionNotifier.updateCurrentUserLocation(location);
      });
    }

    return success;
  }

  /// Stop location sharing
  Future<void> stopLocationSharing() async {
    _locationNotifier.stopPeriodicUpdates();
    await _locationNotifier.stopTracking();
  }

  /// Request location permission and start sharing if granted
  Future<bool> requestPermissionAndStart() async {
    final granted = await _locationNotifier.requestPermission();
    if (granted) {
      return startLocationSharing();
    }
    return false;
  }
}

/// Location accuracy provider
final locationAccuracyProvider = Provider<LocationAccuracy>((ref) {
  final locationState = ref.watch(locationProvider);
  final location = locationState.currentLocation;
  
  if (location == null) return LocationAccuracy.unknown;
  
  final accuracy = location.accuracy;
  if (accuracy <= 5) return LocationAccuracy.excellent;
  if (accuracy <= 10) return LocationAccuracy.good;
  if (accuracy <= 25) return LocationAccuracy.fair;
  if (accuracy <= 50) return LocationAccuracy.poor;
  return LocationAccuracy.veryPoor;
});

/// Location accuracy enum
enum LocationAccuracy {
  excellent,
  good,
  fair,
  poor,
  veryPoor,
  unknown,
}

/// Extension for LocationAccuracy
extension LocationAccuracyExtension on LocationAccuracy {
  String get description {
    switch (this) {
      case LocationAccuracy.excellent:
        return 'Excellent (±5m)';
      case LocationAccuracy.good:
        return 'Good (±10m)';
      case LocationAccuracy.fair:
        return 'Fair (±25m)';
      case LocationAccuracy.poor:
        return 'Poor (±50m)';
      case LocationAccuracy.veryPoor:
        return 'Very Poor (>50m)';
      case LocationAccuracy.unknown:
        return 'Unknown';
    }
  }

  bool get isAcceptable {
    switch (this) {
      case LocationAccuracy.excellent:
      case LocationAccuracy.good:
      case LocationAccuracy.fair:
        return true;
      case LocationAccuracy.poor:
      case LocationAccuracy.veryPoor:
      case LocationAccuracy.unknown:
        return false;
    }
  }
}