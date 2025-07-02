import 'dart:math';

/// Represents a geographic location with timestamp and accuracy
class Location {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;

  const Location({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy = 0.0,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
    };
  }

  Location copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
  }) {
    return Location(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp &&
        other.accuracy == accuracy &&
        other.altitude == altitude &&
        other.speed == speed &&
        other.heading == heading;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      timestamp,
      accuracy,
      altitude,
      speed,
      heading,
    );
  }

  @override
  String toString() {
    return 'Location(lat: $latitude, lng: $longitude, timestamp: $timestamp)';
  }
}

/// Extension methods for Location
extension LocationExtension on Location {
  /// Convert to map for API requests
  Map<String, dynamic> toApiMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  /// Check if location is valid
  bool get isValid {
    return latitude >= -90 && 
           latitude <= 90 && 
           longitude >= -180 && 
           longitude <= 180;
  }

  /// Get location as a formatted string
  String get formatted {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Calculate distance to another location in meters
  double distanceTo(Location other) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = latitude * (pi / 180);
    final double lat2Rad = other.latitude * (pi / 180);
    final double deltaLatRad = (other.latitude - latitude) * (pi / 180);
    final double deltaLonRad = (other.longitude - longitude) * (pi / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Create Location from API response
  static Location fromApiMap(Map<String, dynamic> map) {
    return Location(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents location bounds for map view
class LocationBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const LocationBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  factory LocationBounds.fromJson(Map<String, dynamic> json) {
    return LocationBounds(
      north: (json['north'] as num).toDouble(),
      south: (json['south'] as num).toDouble(),
      east: (json['east'] as num).toDouble(),
      west: (json['west'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'north': north,
      'south': south,
      'east': east,
      'west': west,
    };
  }

  LocationBounds copyWith({
    double? north,
    double? south,
    double? east,
    double? west,
  }) {
    return LocationBounds(
      north: north ?? this.north,
      south: south ?? this.south,
      east: east ?? this.east,
      west: west ?? this.west,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationBounds &&
        other.north == north &&
        other.south == south &&
        other.east == east &&
        other.west == west;
  }

  @override
  int get hashCode => Object.hash(north, south, east, west);

  @override
  String toString() {
    return 'LocationBounds(north: $north, south: $south, east: $east, west: $west)';
  }
}

/// Extension methods for LocationBounds
extension LocationBoundsExtension on LocationBounds {
  /// Check if bounds are valid
  bool get isValid {
    return north > south && east > west &&
           north <= 90 && south >= -90 &&
           east <= 180 && west >= -180;
  }

  /// Get center point of bounds
  Location get center {
    return Location(
      latitude: (north + south) / 2,
      longitude: (east + west) / 2,
      timestamp: DateTime.now(),
    );
  }

  /// Check if location is within bounds
  bool contains(Location location) {
    return location.latitude >= south &&
           location.latitude <= north &&
           location.longitude >= west &&
           location.longitude <= east;
  }

  /// Expand bounds to include a location
  LocationBounds expandToInclude(Location location) {
    return LocationBounds(
      north: location.latitude > north ? location.latitude : north,
      south: location.latitude < south ? location.latitude : south,
      east: location.longitude > east ? location.longitude : east,
      west: location.longitude < west ? location.longitude : west,
    );
  }

  /// Create bounds from a list of locations
  static LocationBounds? fromLocations(List<Location> locations) {
    if (locations.isEmpty) return null;

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    return LocationBounds(
      north: maxLat,
      south: minLat,
      east: maxLng,
      west: minLng,
    );
  }
}