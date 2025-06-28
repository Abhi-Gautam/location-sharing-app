import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/participant.dart';
import '../models/location.dart';
import 'session_provider.dart';

/// Provider for all participants in the current session
final participantsProvider = Provider<ParticipantList>((ref) {
  final sessionState = ref.watch(sessionProvider);
  return sessionState.participants;
});

/// Provider for active participants only
final activeParticipantsProvider = Provider<List<Participant>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.activeParticipants;
});

/// Provider for online participants only
final onlineParticipantsProvider = Provider<List<Participant>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.onlineParticipants;
});

/// Provider for participants with current location
final participantsWithLocationProvider = Provider<List<Participant>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.participantsWithLocation;
});

/// Provider for a specific participant by ID
final participantByIdProvider = Provider.family<Participant?, String>((ref, userId) {
  final participants = ref.watch(participantsProvider);
  return participants.findById(userId);
});

/// Provider for current user participant
final currentUserParticipantProvider = Provider<Participant?>((ref) {
  final sessionState = ref.watch(sessionProvider);
  return sessionState.currentUser;
});

/// Provider for participant count
final participantCountProvider = Provider<int>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.count;
});

/// Provider for active participant count
final activeParticipantCountProvider = Provider<int>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.activeCount;
});

/// Provider for online participant count
final onlineParticipantCountProvider = Provider<int>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.onlineCount;
});

/// Provider for all participant locations
final allParticipantLocationsProvider = Provider<List<Location>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.allLocations;
});

/// Provider that combines participants with their status information
final participantsWithStatusProvider = Provider<List<ParticipantWithStatus>>((ref) {
  final participants = ref.watch(activeParticipantsProvider);
  final currentUserId = ref.watch(sessionProvider).currentUserId;
  
  return participants.map((participant) {
    return ParticipantWithStatus(
      participant: participant,
      isCurrentUser: participant.userId == currentUserId,
      hasLocation: participant.currentLocation != null,
      isOnline: participant.isOnline,
      status: _getParticipantStatus(participant),
    );
  }).toList();
});

/// Provider for participants sorted by various criteria
final sortedParticipantsProvider = Provider.family<List<Participant>, ParticipantSortCriteria>((ref, criteria) {
  final participants = ref.watch(activeParticipantsProvider);
  final currentUserId = ref.watch(sessionProvider).currentUserId;
  
  final sortedList = List<Participant>.from(participants);
  
  sortedList.sort((a, b) {
    // Always put current user first
    if (a.userId == currentUserId) return -1;
    if (b.userId == currentUserId) return 1;
    
    switch (criteria) {
      case ParticipantSortCriteria.name:
        return a.displayName.compareTo(b.displayName);
      case ParticipantSortCriteria.joinTime:
        return a.joinedAt.compareTo(b.joinedAt);
      case ParticipantSortCriteria.lastSeen:
        return b.lastSeen.compareTo(a.lastSeen);
      case ParticipantSortCriteria.online:
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.displayName.compareTo(b.displayName);
    }
  });
  
  return sortedList;
});

/// Provider for participants grouped by status
final participantsGroupedByStatusProvider = Provider<Map<ParticipantStatusGroup, List<Participant>>>((ref) {
  final participants = ref.watch(activeParticipantsProvider);
  
  final Map<ParticipantStatusGroup, List<Participant>> grouped = {
    ParticipantStatusGroup.online: [],
    ParticipantStatusGroup.recent: [],
    ParticipantStatusGroup.offline: [],
  };
  
  for (final participant in participants) {
    if (participant.isOnline) {
      grouped[ParticipantStatusGroup.online]!.add(participant);
    } else {
      final timeSinceLastSeen = DateTime.now().difference(participant.lastSeen);
      if (timeSinceLastSeen.inMinutes <= 5) {
        grouped[ParticipantStatusGroup.recent]!.add(participant);
      } else {
        grouped[ParticipantStatusGroup.offline]!.add(participant);
      }
    }
  }
  
  return grouped;
});

/// Provider for participant statistics
final participantStatsProvider = Provider<ParticipantStats>((ref) {
  final allParticipants = ref.watch(participantsProvider);
  final activeParticipants = ref.watch(activeParticipantsProvider);
  final onlineParticipants = ref.watch(onlineParticipantsProvider);
  final participantsWithLocation = ref.watch(participantsWithLocationProvider);
  
  return ParticipantStats(
    total: allParticipants.count,
    active: activeParticipants.length,
    online: onlineParticipants.length,
    withLocation: participantsWithLocation.length,
    offline: activeParticipants.length - onlineParticipants.length,
  );
});

/// Provider for checking if current user can perform admin actions
final canPerformAdminActionsProvider = Provider<bool>((ref) {
  final sessionState = ref.watch(sessionProvider);
  return sessionState.isCreator;
});

/// Provider for participant distance calculations
final participantDistancesProvider = Provider.family<Map<String, double>, Location>((ref, referenceLocation) {
  final participants = ref.watch(participantsWithLocationProvider);
  final Map<String, double> distances = {};
  
  for (final participant in participants) {
    if (participant.currentLocation != null) {
      final distance = referenceLocation.distanceTo(participant.currentLocation!);
      distances[participant.userId] = distance;
    }
  }
  
  return distances;
});

/// Provider for nearest participants
final nearestParticipantsProvider = Provider.family<List<ParticipantWithDistance>, Location>((ref, referenceLocation) {
  final participants = ref.watch(participantsWithLocationProvider);
  final List<ParticipantWithDistance> participantsWithDistance = [];
  
  for (final participant in participants) {
    if (participant.currentLocation != null) {
      final distance = referenceLocation.distanceTo(participant.currentLocation!);
      participantsWithDistance.add(ParticipantWithDistance(
        participant: participant,
        distance: distance,
      ));
    }
  }
  
  // Sort by distance
  participantsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
  
  return participantsWithDistance;
});

/// Helper function to get participant status
ParticipantStatus _getParticipantStatus(Participant participant) {
  if (!participant.isActive) return ParticipantStatus.left;
  if (participant.isOnline) return ParticipantStatus.online;
  
  final timeSinceLastSeen = DateTime.now().difference(participant.lastSeen);
  if (timeSinceLastSeen.inMinutes <= 1) {
    return ParticipantStatus.justLeft;
  } else if (timeSinceLastSeen.inMinutes <= 5) {
    return ParticipantStatus.recent;
  } else {
    return ParticipantStatus.offline;
  }
}

/// Data class for participant with additional status information
class ParticipantWithStatus {
  final Participant participant;
  final bool isCurrentUser;
  final bool hasLocation;
  final bool isOnline;
  final ParticipantStatus status;

  const ParticipantWithStatus({
    required this.participant,
    required this.isCurrentUser,
    required this.hasLocation,
    required this.isOnline,
    required this.status,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantWithStatus &&
        other.participant == participant &&
        other.isCurrentUser == isCurrentUser &&
        other.hasLocation == hasLocation &&
        other.isOnline == isOnline &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      participant,
      isCurrentUser,
      hasLocation,
      isOnline,
      status,
    );
  }
}

/// Data class for participant with distance information
class ParticipantWithDistance {
  final Participant participant;
  final double distance; // in meters

  const ParticipantWithDistance({
    required this.participant,
    required this.distance,
  });

  /// Get formatted distance string
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      final km = distance / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantWithDistance &&
        other.participant == participant &&
        other.distance == distance;
  }

  @override
  int get hashCode => Object.hash(participant, distance);
}

/// Statistics about participants in the session
class ParticipantStats {
  final int total;
  final int active;
  final int online;
  final int offline;
  final int withLocation;

  const ParticipantStats({
    required this.total,
    required this.active,
    required this.online,
    required this.offline,
    required this.withLocation,
  });

  /// Get participation rate (active / total)
  double get participationRate {
    if (total == 0) return 0.0;
    return active / total;
  }

  /// Get online rate (online / active)
  double get onlineRate {
    if (active == 0) return 0.0;
    return online / active;
  }

  /// Get location sharing rate (withLocation / active)
  double get locationSharingRate {
    if (active == 0) return 0.0;
    return withLocation / active;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantStats &&
        other.total == total &&
        other.active == active &&
        other.online == online &&
        other.offline == offline &&
        other.withLocation == withLocation;
  }

  @override
  int get hashCode {
    return Object.hash(total, active, online, offline, withLocation);
  }

  @override
  String toString() {
    return 'ParticipantStats(total: $total, active: $active, online: $online, withLocation: $withLocation)';
  }
}

/// Enum for participant sort criteria
enum ParticipantSortCriteria {
  name,
  joinTime,
  lastSeen,
  online,
}

/// Enum for participant status groups
enum ParticipantStatusGroup {
  online,
  recent,
  offline,
}

/// Enum for detailed participant status
enum ParticipantStatus {
  online,
  justLeft,
  recent,
  offline,
  left,
}

/// Extension for ParticipantStatus
extension ParticipantStatusExtension on ParticipantStatus {
  /// Get status display text
  String get displayText {
    switch (this) {
      case ParticipantStatus.online:
        return 'Online';
      case ParticipantStatus.justLeft:
        return 'Just left';
      case ParticipantStatus.recent:
        return 'Recently active';
      case ParticipantStatus.offline:
        return 'Offline';
      case ParticipantStatus.left:
        return 'Left session';
    }
  }

  /// Get status color
  Color get color {
    switch (this) {
      case ParticipantStatus.online:
        return const Color(0xFF4CAF50); // Green
      case ParticipantStatus.justLeft:
        return const Color(0xFFFF9800); // Orange
      case ParticipantStatus.recent:
        return const Color(0xFFFF9800); // Orange
      case ParticipantStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case ParticipantStatus.left:
        return const Color(0xFFE53E3E); // Red
    }
  }

  /// Check if status indicates participant is currently active
  bool get isActive {
    switch (this) {
      case ParticipantStatus.online:
      case ParticipantStatus.justLeft:
      case ParticipantStatus.recent:
        return true;
      case ParticipantStatus.offline:
      case ParticipantStatus.left:
        return false;
    }
  }
}

/// Extension for ParticipantSortCriteria
extension ParticipantSortCriteriaExtension on ParticipantSortCriteria {
  /// Get display name for sort criteria
  String get displayName {
    switch (this) {
      case ParticipantSortCriteria.name:
        return 'Name';
      case ParticipantSortCriteria.joinTime:
        return 'Join Time';
      case ParticipantSortCriteria.lastSeen:
        return 'Last Seen';
      case ParticipantSortCriteria.online:
        return 'Online Status';
    }
  }

  /// Get icon for sort criteria
  IconData get icon {
    switch (this) {
      case ParticipantSortCriteria.name:
        return Icons.sort_by_alpha;
      case ParticipantSortCriteria.joinTime:
        return Icons.schedule;
      case ParticipantSortCriteria.lastSeen:
        return Icons.update;
      case ParticipantSortCriteria.online:
        return Icons.online_prediction;
    }
  }
}

/// Import statements that might be missing
import 'package:flutter/material.dart';