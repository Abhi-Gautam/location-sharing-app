import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/participant.dart';
import '../models/location.dart' as app_location;

/// Interactive Google Maps widget for real-time location sharing
class MapWidget extends StatefulWidget {
  final Function(GoogleMapController)? onMapCreated;
  final List<Participant> participants;
  final app_location.Location? currentLocation;
  final Function(String participantId)? onMarkerTap;
  final bool showMyLocationButton;
  final bool enableRotation;
  final bool enableTilt;
  final MapType mapType;

  const MapWidget({
    super.key,
    this.onMapCreated,
    this.participants = const [],
    this.currentLocation,
    this.onMarkerTap,
    this.showMyLocationButton = true,
    this.enableRotation = true,
    this.enableTilt = true,
    this.mapType = MapType.normal,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  
  CameraPosition? _lastCameraPosition;
  bool _isMapReady = false;
  
  // Cache for custom marker icons
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.participants != widget.participants ||
        oldWidget.currentLocation != widget.currentLocation) {
      _updateMarkersAndCircles();
    }
  }

  void _initializeMap() {
    // Initialize with default location or current location
    final initialLocation = widget.currentLocation ??
        app_location.Location(
          latitude: AppConstants.defaultLatitude,
          longitude: AppConstants.defaultLongitude,
          timestamp: DateTime.now(),
        );

    _lastCameraPosition = CameraPosition(
      target: LatLng(initialLocation.latitude, initialLocation.longitude),
      zoom: AppConfig.defaultMapZoom,
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    _isMapReady = true;

    // Set custom map style (optional)
    try {
      final String mapStyle = await rootBundle.loadString('assets/map_style.json');
      await controller.setMapStyle(mapStyle);
    } catch (e) {
      // Map style is optional, continue without it
      debugPrint('Could not load map style: $e');
    }

    // Call the callback
    widget.onMapCreated?.call(controller);

    // Update markers after map is ready
    _updateMarkersAndCircles();
  }

  void _onCameraMove(CameraPosition position) {
    _lastCameraPosition = position;
  }

  Future<void> _updateMarkersAndCircles() async {
    if (!_isMapReady) return;

    final Set<Marker> markers = {};
    final Set<Circle> circles = {};

    // Add markers for all participants
    for (final participant in widget.participants) {
      if (participant.currentLocation != null) {
        final marker = await _createParticipantMarker(participant);
        if (marker != null) {
          markers.add(marker);
          
          // Add accuracy circle
          final circle = _createAccuracyCircle(participant);
          if (circle != null) {
            circles.add(circle);
          }
        }
      }
    }

    // Add marker for current user location
    if (widget.currentLocation != null) {
      final currentUserMarker = await _createCurrentUserMarker();
      if (currentUserMarker != null) {
        markers.add(currentUserMarker);
        
        // Add accuracy circle for current user
        final currentUserCircle = _createCurrentUserAccuracyCircle();
        if (currentUserCircle != null) {
          circles.add(currentUserCircle);
        }
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _circles = circles;
      });
    }
  }

  Future<Marker?> _createParticipantMarker(Participant participant) async {
    final location = participant.currentLocation;
    if (location == null) return null;

    try {
      final icon = await _getParticipantMarkerIcon(participant);
      
      return Marker(
        markerId: MarkerId('participant_${participant.userId}'),
        position: LatLng(location.latitude, location.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: participant.displayName,
          snippet: participant.statusText,
        ),
        onTap: () => widget.onMarkerTap?.call(participant.userId),
        zIndex: 1,
      );
    } catch (e) {
      debugPrint('Error creating participant marker: $e');
      return null;
    }
  }

  Future<Marker?> _createCurrentUserMarker() async {
    final location = widget.currentLocation;
    if (location == null) return null;

    try {
      final icon = await _getCurrentUserMarkerIcon();
      
      return Marker(
        markerId: const MarkerId('current_user'),
        position: LatLng(location.latitude, location.longitude),
        icon: icon,
        infoWindow: const InfoWindow(
          title: 'You',
          snippet: 'Your current location',
        ),
        zIndex: 2,
      );
    } catch (e) {
      debugPrint('Error creating current user marker: $e');
      return null;
    }
  }

  Circle? _createAccuracyCircle(Participant participant) {
    final location = participant.currentLocation;
    if (location == null || location.accuracy <= 0) return null;

    final color = AppUtils.hexToColor(participant.avatarColor);
    
    return Circle(
      circleId: CircleId('accuracy_${participant.userId}'),
      center: LatLng(location.latitude, location.longitude),
      radius: location.accuracy,
      fillColor: color.withOpacity(0.1),
      strokeColor: color.withOpacity(0.3),
      strokeWidth: 1,
    );
  }

  Circle? _createCurrentUserAccuracyCircle() {
    final location = widget.currentLocation;
    if (location == null || location.accuracy <= 0) return null;

    return Circle(
      circleId: const CircleId('current_user_accuracy'),
      center: LatLng(location.latitude, location.longitude),
      radius: location.accuracy,
      fillColor: Colors.blue.withOpacity(0.1),
      strokeColor: Colors.blue.withOpacity(0.3),
      strokeWidth: 2,
    );
  }

  Future<BitmapDescriptor> _getParticipantMarkerIcon(Participant participant) async {
    final cacheKey = 'participant_${participant.avatarColor}';
    
    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    final icon = await _createCustomMarkerIcon(
      color: AppUtils.hexToColor(participant.avatarColor),
      text: participant.initials,
      size: AppConstants.markerSize,
      isCurrentUser: false,
    );

    _markerIconCache[cacheKey] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _getCurrentUserMarkerIcon() async {
    const cacheKey = 'current_user';
    
    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    final icon = await _createCustomMarkerIcon(
      color: Colors.blue,
      text: 'ME',
      size: AppConstants.markerSize,
      isCurrentUser: true,
    );

    _markerIconCache[cacheKey] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon({
    required Color color,
    required String text,
    required double size,
    required bool isCurrentUser,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double radius = size / 2;

    // Draw outer circle (border)
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, outerPaint);

    // Draw inner circle
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius - 3, innerPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = isCurrentUser ? Colors.blue.shade700 : color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCurrentUser ? 4 : 2;
    canvas.drawCircle(Offset(radius, radius), radius - 1.5, borderPaint);

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: size * 0.25,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - textPainter.width / 2,
        radius - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Widget _buildMapTypeSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 16, right: 16),
      child: Material(
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MapType>(
              value: widget.mapType,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              style: Theme.of(context).textTheme.bodySmall,
              items: const [
                DropdownMenuItem(
                  value: MapType.normal,
                  child: Text('Normal'),
                ),
                DropdownMenuItem(
                  value: MapType.satellite,
                  child: Text('Satellite'),
                ),
                DropdownMenuItem(
                  value: MapType.hybrid,
                  child: Text('Hybrid'),
                ),
                DropdownMenuItem(
                  value: MapType.terrain,
                  child: Text('Terrain'),
                ),
              ],
              onChanged: null, // Disable for now
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapLoadingOverlay() {
    return Container(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading map...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          onCameraMove: _onCameraMove,
          initialCameraPosition: _lastCameraPosition ?? const CameraPosition(
            target: LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude),
            zoom: AppConfig.defaultMapZoom,
          ),
          markers: _markers,
          circles: _circles,
          mapType: widget.mapType,
          myLocationEnabled: false, // We handle this with custom markers
          myLocationButtonEnabled: false, // We handle this with custom button
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          rotateGesturesEnabled: widget.enableRotation,
          tiltGesturesEnabled: widget.enableTilt,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          minMaxZoomPreference: const MinMaxZoomPreference(
            AppConfig.minMapZoom,
            AppConfig.maxMapZoom,
          ),
          padding: const EdgeInsets.all(16),
        ),
        
        // Map type selector
        Positioned(
          top: 0,
          right: 0,
          child: _buildMapTypeSelector(),
        ),

        // Loading overlay
        if (!_isMapReady)
          _buildMapLoadingOverlay(),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Extension methods for MapWidget
extension MapWidgetExtensions on _MapWidgetState {
  /// Animate camera to show all participants
  Future<void> animateToShowAllParticipants() async {
    if (_controller == null || widget.participants.isEmpty) return;

    final locations = widget.participants
        .map((p) => p.currentLocation)
        .where((location) => location != null)
        .cast<app_location.Location>()
        .toList();

    if (widget.currentLocation != null) {
      locations.add(widget.currentLocation!);
    }

    if (locations.isNotEmpty) {
      final bounds = app_location.LocationBoundsExtension.fromLocations(locations);
      if (bounds != null) {
        await _controller!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(bounds.south, bounds.west),
              northeast: LatLng(bounds.north, bounds.east),
            ),
            100.0, // padding
          ),
        );
      }
    }
  }

  /// Animate camera to specific location
  Future<void> animateToLocation(app_location.Location location, {double? zoom}) async {
    if (_controller == null) return;

    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.latitude, location.longitude),
          zoom: zoom ?? AppConfig.defaultMapZoom,
        ),
      ),
    );
  }
}

/// Map interaction callbacks
class MapInteractionCallbacks {
  final VoidCallback? onMyLocationTap;
  final Function(LatLng)? onMapTap;
  final Function(LatLng)? onMapLongPress;
  final Function(String participantId)? onParticipantMarkerTap;

  const MapInteractionCallbacks({
    this.onMyLocationTap,
    this.onMapTap,
    this.onMapLongPress,
    this.onParticipantMarkerTap,
  });
}

/// Map configuration options
class MapConfiguration {
  final MapType mapType;
  final bool showMyLocationButton;
  final bool showMapTypeSelector;
  final bool enableRotation;
  final bool enableTilt;
  final bool showAccuracyCircles;
  final double defaultZoom;
  final double minZoom;
  final double maxZoom;

  const MapConfiguration({
    this.mapType = MapType.normal,
    this.showMyLocationButton = true,
    this.showMapTypeSelector = true,
    this.enableRotation = true,
    this.enableTilt = true,
    this.showAccuracyCircles = true,
    this.defaultZoom = AppConfig.defaultMapZoom,
    this.minZoom = AppConfig.minMapZoom,
    this.maxZoom = AppConfig.maxMapZoom,
  });
}