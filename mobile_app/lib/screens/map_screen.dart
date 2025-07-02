import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';
import '../core/utils.dart';
import '../core/constants.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../providers/location_provider.dart';
import '../providers/participants_provider.dart';
import '../widgets/participant_avatar.dart';
import '../widgets/session_controls.dart';
import '../widgets/map_widget.dart';
import '../models/participant.dart';
import '../models/location.dart';
import '../core/extensions.dart';

/// Map screen showing real-time location sharing
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  bool _isMapReady = false;
  bool _isCentering = false;

  @override
  void initState() {
    super.initState();
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOut,
    ));

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final locationState = ref.watch(locationProvider);
    final participants = ref.watch(participantsWithLocationProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          _buildMap(participants, locationState),
          
          // Top overlay with session info
          _buildTopOverlay(sessionState),
          
          // Bottom overlay with participants
          _buildBottomOverlay(participants),
          
          // Session controls
          _buildSessionControls(),
          
          // Floating action buttons
          _buildFloatingActions(participants, locationState),
        ],
      ),
    );
  }

  Widget _buildMap(List<Participant> participants, LocationState locationState) {
    return MapWidget(
      onMapCreated: (controller) {
        _mapController = controller;
        setState(() {
          _isMapReady = true;
        });
      },
      participants: participants,
      currentLocation: locationState.currentLocation,
      onMarkerTap: (participantId) {
        _showParticipantBottomSheet(participantId);
      },
    );
  }

  Widget _buildTopOverlay(SessionState sessionState) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getConnectionStatusColor(sessionState.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sessionState.sessionDisplayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getStatusText(sessionState),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (sessionState.session?.remainingTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sessionState.session!.remainingTimeFormatted,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(List<Participant> participants) {
    if (participants.isEmpty) {
      return Positioned(
        bottom: 16,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for participants to share their location...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Participants (${participants.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showAllParticipants(),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  return _buildParticipantItem(participant);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantItem(Participant participant) {
    return GestureDetector(
      onTap: () => _centerOnParticipant(participant),
      child: Container(
        width: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ParticipantAvatar(
              participant: participant,
              size: 36,
              showOnlineIndicator: true,
            ),
            const SizedBox(height: 4),
            Text(
              participant.displayName,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      right: 16,
      child: SessionControls(
        onLeaveSession: () => _leaveSession(),
        onEndSession: () => _endSession(),
        onToggleLocationSharing: () => _toggleLocationSharing(),
      ),
    );
  }

  Widget _buildFloatingActions(List<Participant> participants, LocationState locationState) {
    return Positioned(
      bottom: 120,
      right: 16,
      child: Column(
        children: [
          // Center on all participants
          if (participants.length > 1)
            ScaleTransition(
              scale: _fabAnimation,
              child: FloatingActionButton(
                heroTag: 'center_all',
                mini: true,
                onPressed: _isCentering ? null : () => _centerOnAllParticipants(participants),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                child: _isCentering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.center_focus_strong),
              ),
            ),
          
          if (participants.length > 1) const SizedBox(height: 8),
          
          // Center on me
          ScaleTransition(
            scale: _fabAnimation,
            child: FloatingActionButton(
              heroTag: 'center_me',
              mini: true,
              onPressed: _isCentering ? null : () => _centerOnCurrentUser(locationState),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: _isCentering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConnectionStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.connected:
        return Colors.green;
      case SessionStatus.connecting:
      case SessionStatus.reconnecting:
        return Colors.orange;
      case SessionStatus.error:
        return Colors.red;
      case SessionStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusText(SessionState sessionState) {
    switch (sessionState.status) {
      case SessionStatus.connected:
        return 'Connected • Live location sharing';
      case SessionStatus.connecting:
        return 'Connecting...';
      case SessionStatus.reconnecting:
        return 'Reconnecting...';
      case SessionStatus.error:
        return 'Connection error';
      case SessionStatus.disconnected:
        return 'Disconnected';
      default:
        return 'Unknown status';
    }
  }

  Future<void> _centerOnAllParticipants(List<Participant> participants) async {
    if (_mapController == null || participants.isEmpty) return;

    setState(() {
      _isCentering = true;
    });

    try {
      final locations = participants
          .map((p) => p.currentLocation)
          .where((location) => location != null)
          .cast<Location>()
          .toList();

      if (locations.isNotEmpty) {
        final bounds = LocationBoundsExtension.fromLocations(locations);
        if (bounds != null) {
          await _mapController!.animateCamera(
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
    } catch (e) {
      debugPrint('Error centering on all participants: $e');
    } finally {
      setState(() {
        _isCentering = false;
      });
    }
  }

  Future<void> _centerOnCurrentUser(LocationState locationState) async {
    if (_mapController == null || locationState.currentLocation == null) return;

    setState(() {
      _isCentering = true;
    });

    try {
      final location = locationState.currentLocation!;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: AppConfig.defaultMapZoom,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error centering on current user: $e');
    } finally {
      setState(() {
        _isCentering = false;
      });
    }
  }

  Future<void> _centerOnParticipant(Participant participant) async {
    if (_mapController == null || participant.currentLocation == null) return;

    setState(() {
      _isCentering = true;
    });

    try {
      final location = participant.currentLocation!;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: AppConfig.defaultMapZoom,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error centering on participant: $e');
    } finally {
      setState(() {
        _isCentering = false;
      });
    }
  }

  void _showParticipantBottomSheet(String participantId) {
    final participant = ref.read(participantByIdProvider(participantId));
    if (participant == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParticipantAvatar(
              participant: participant,
              size: 64,
              showOnlineIndicator: true,
            ),
            const SizedBox(height: 16),
            Text(
              participant.displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              participant.statusText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (participant.currentLocation != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLocationInfo(
                    'Accuracy',
                    '±${participant.currentLocation!.accuracy.round()}m',
                    Icons.gps_fixed,
                  ),
                  _buildLocationInfo(
                    'Updated',
                    participant.currentLocation!.timestamp.relativeTime,
                    Icons.access_time,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _centerOnParticipant(participant);
                    },
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Center on Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showAllParticipants() {
    final participants = ref.read(activeParticipantsProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All Participants (${participants.length})',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    return ListTile(
                      leading: ParticipantAvatar(
                        participant: participant,
                        size: 40,
                        showOnlineIndicator: true,
                      ),
                      title: Text(participant.displayName),
                      subtitle: Text(participant.statusText),
                      trailing: participant.currentLocation != null
                          ? IconButton(
                              icon: const Icon(Icons.center_focus_strong),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _centerOnParticipant(participant);
                              },
                            )
                          : null,
                      onTap: () => _showParticipantBottomSheet(participant.userId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _leaveSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session'),
        content: const Text(
          'Are you sure you want to leave this location sharing session? '
          'You will stop sharing your location with other participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(sessionProvider.notifier).leaveSession();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _endSession() {
    final sessionState = ref.read(sessionProvider);
    if (!sessionState.isCreator) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text(
          'Are you sure you want to end this session? '
          'This will disconnect all participants and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(sessionProvider.notifier).endSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  void _toggleLocationSharing() {
    final locationState = ref.read(locationProvider);
    final locationController = ref.read(locationTrackingControllerProvider);

    if (locationState.isTracking) {
      locationController.stopLocationSharing();
      AppUtils.showInfoSnackbar(context, 'Location sharing stopped');
    } else {
      locationController.startLocationSharing().then((success) {
        if (success) {
          AppUtils.showSuccessSnackbar(context, 'Location sharing started');
        } else {
          AppUtils.showErrorSnackbar(context, 'Failed to start location sharing');
        }
      });
    }
  }
}