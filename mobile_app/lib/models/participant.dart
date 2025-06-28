import 'location.dart';

/// Represents a participant in a location sharing session
class Participant {
  final String userId;
  final String displayName;
  final String avatarColor;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool isActive;
  final Location? currentLocation;

  const Participant({
    required this.userId,
    required this.displayName,
    required this.avatarColor,
    required this.joinedAt,
    required this.lastSeen,
    this.isActive = true,
    this.currentLocation,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      avatarColor: json['avatarColor'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      isActive: json['isActive'] as bool? ?? true,
      currentLocation: json['currentLocation'] != null
          ? Location.fromJson(json['currentLocation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarColor': avatarColor,
      'joinedAt': joinedAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'isActive': isActive,
      'currentLocation': currentLocation?.toJson(),
    };
  }

  Participant copyWith({
    String? userId,
    String? displayName,
    String? avatarColor,
    DateTime? joinedAt,
    DateTime? lastSeen,
    bool? isActive,
    Location? currentLocation,
  }) {
    return Participant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isActive: isActive ?? this.isActive,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Participant &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.avatarColor == avatarColor &&
        other.joinedAt == joinedAt &&
        other.lastSeen == lastSeen &&
        other.isActive == isActive &&
        other.currentLocation == currentLocation;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      displayName,
      avatarColor,
      joinedAt,
      lastSeen,
      isActive,
      currentLocation,
    );
  }

  @override
  String toString() {
    return 'Participant(userId: $userId, displayName: $displayName, isActive: $isActive)';
  }
}

/// Extension methods for Participant
extension ParticipantExtension on Participant {
  /// Convert to map for API requests
  Map<String, dynamic> toApiMap() {
    return {
      'display_name': displayName,
      'avatar_color': avatarColor,
    };
  }

  /// Create Participant from API response
  static Participant fromApiMap(Map<String, dynamic> map) {
    return Participant(
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String,
      avatarColor: map['avatar_color'] as String? ?? '#FF5733',
      joinedAt: DateTime.parse(map['joined_at'] as String? ?? DateTime.now().toIso8601String()),
      lastSeen: DateTime.parse(map['last_seen'] as String? ?? DateTime.now().toIso8601String()),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  /// Check if participant is currently online (last seen within 30 seconds)
  bool get isOnline {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    return isActive && difference.inSeconds <= 30;
  }

  /// Get status text for participant
  String get statusText {
    if (!isActive) return 'Left';
    if (isOnline) return 'Online';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Get initials from display name
  String get initials {
    final words = displayName.trim().split(' ');
    if (words.isEmpty) return 'U';
    
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word.toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Update participant with new location
  Participant updateLocation(Location location) {
    return copyWith(
      currentLocation: location,
      lastSeen: DateTime.now(),
    );
  }

  /// Update participant's last seen timestamp
  Participant updateLastSeen() {
    return copyWith(lastSeen: DateTime.now());
  }

  /// Mark participant as active/inactive
  Participant setActive(bool active) {
    return copyWith(
      isActive: active,
      lastSeen: DateTime.now(),
    );
  }
}

/// Represents a collection of participants with utility methods
class ParticipantList {
  final List<Participant> participants;

  const ParticipantList({
    this.participants = const [],
  });

  factory ParticipantList.fromJson(Map<String, dynamic> json) {
    final participantsList = json['participants'] as List<dynamic>? ?? [];
    return ParticipantList(
      participants: participantsList
          .map((p) => Participant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants.map((p) => p.toJson()).toList(),
    };
  }

  ParticipantList copyWith({
    List<Participant>? participants,
  }) {
    return ParticipantList(
      participants: participants ?? this.participants,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantList && 
        _listEquals(other.participants, participants);
  }

  @override
  int get hashCode => participants.hashCode;

  @override
  String toString() {
    return 'ParticipantList(count: ${participants.length})';
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Extension methods for ParticipantList
extension ParticipantListExtension on ParticipantList {
  /// Get active participants only
  List<Participant> get activeParticipants {
    return participants.where((p) => p.isActive).toList();
  }

  /// Get online participants only
  List<Participant> get onlineParticipants {
    return participants.where((p) => p.isOnline).toList();
  }

  /// Get participants with current location
  List<Participant> get participantsWithLocation {
    return participants.where((p) => p.currentLocation != null).toList();
  }

  /// Find participant by user ID
  Participant? findById(String userId) {
    try {
      return participants.firstWhere((p) => p.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if participant exists
  bool contains(String userId) {
    return participants.any((p) => p.userId == userId);
  }

  /// Add or update participant
  ParticipantList addOrUpdate(Participant participant) {
    final existingIndex = participants.indexWhere((p) => p.userId == participant.userId);
    
    if (existingIndex >= 0) {
      final updatedParticipants = List<Participant>.from(participants);
      updatedParticipants[existingIndex] = participant;
      return copyWith(participants: updatedParticipants);
    } else {
      return copyWith(participants: [...participants, participant]);
    }
  }

  /// Remove participant
  ParticipantList remove(String userId) {
    final updatedParticipants = participants.where((p) => p.userId != userId).toList();
    return copyWith(participants: updatedParticipants);
  }

  /// Update participant location
  ParticipantList updateLocation(String userId, Location location) {
    final participant = findById(userId);
    if (participant != null) {
      final updatedParticipant = participant.updateLocation(location);
      return addOrUpdate(updatedParticipant);
    }
    return this;
  }

  /// Get all current locations
  List<Location> get allLocations {
    return participants
        .map((p) => p.currentLocation)
        .where((location) => location != null)
        .cast<Location>()
        .toList();
  }

  /// Get participant count
  int get count => participants.length;

  /// Get active participant count
  int get activeCount => activeParticipants.length;

  /// Get online participant count
  int get onlineCount => onlineParticipants.length;
}