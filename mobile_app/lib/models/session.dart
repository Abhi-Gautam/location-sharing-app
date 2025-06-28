import 'participant.dart';

/// Represents a location sharing session
class Session {
  final String id;
  final String? name;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String creatorId;
  final bool isActive;
  final int participantCount;
  final DateTime? lastActivity;

  const Session({
    required this.id,
    this.name,
    required this.createdAt,
    required this.expiresAt,
    required this.creatorId,
    this.isActive = true,
    this.participantCount = 0,
    this.lastActivity,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      creatorId: json['creatorId'] as String,
      isActive: json['isActive'] as bool? ?? true,
      participantCount: json['participantCount'] as int? ?? 0,
      lastActivity: json['lastActivity'] != null 
          ? DateTime.parse(json['lastActivity'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'creatorId': creatorId,
      'isActive': isActive,
      'participantCount': participantCount,
      'lastActivity': lastActivity?.toIso8601String(),
    };
  }

  Session copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? creatorId,
    bool? isActive,
    int? participantCount,
    DateTime? lastActivity,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      creatorId: creatorId ?? this.creatorId,
      isActive: isActive ?? this.isActive,
      participantCount: participantCount ?? this.participantCount,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session &&
        other.id == id &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt &&
        other.creatorId == creatorId &&
        other.isActive == isActive &&
        other.participantCount == participantCount &&
        other.lastActivity == lastActivity;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      createdAt,
      expiresAt,
      creatorId,
      isActive,
      participantCount,
      lastActivity,
    );
  }

  @override
  String toString() {
    return 'Session(id: $id, name: $name, isActive: $isActive)';
  }
}

/// Extension methods for Session
extension SessionExtension on Session {
  /// Create Session from API response
  static Session fromApiMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      name: map['name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      creatorId: map['creator_id'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? true,
      participantCount: map['participant_count'] as int? ?? 0,
      lastActivity: map['last_activity'] != null 
          ? DateTime.parse(map['last_activity'] as String)
          : null,
    );
  }

  /// Convert to map for API requests
  Map<String, dynamic> toApiMap() {
    final map = <String, dynamic>{};
    if (name != null && name!.isNotEmpty) {
      map['name'] = name;
    }
    return map;
  }

  /// Check if session is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Check if session is valid (active and not expired)
  bool get isValid {
    return isActive && !isExpired;
  }

  /// Get remaining time until expiration
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  /// Get time since creation
  Duration get age {
    return DateTime.now().difference(createdAt);
  }

  /// Get formatted remaining time
  String get remainingTimeFormatted {
    final duration = remainingTime;
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Expired';
    }
  }

  /// Get display name for session
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return 'Session ${id.substring(0, 8)}';
  }

  /// Generate join link
  String generateJoinLink({String baseUrl = 'https://app.locationsharing.com'}) {
    return '$baseUrl/join/$id';
  }

  /// Check if user is the creator
  bool isCreator(String userId) {
    return creatorId == userId;
  }
}

/// Request model for creating a new session
class CreateSessionRequest {
  final String? name;
  final int expiresInMinutes;

  const CreateSessionRequest({
    this.name,
    this.expiresInMinutes = 1440, // 24 hours default
  });

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) {
    return CreateSessionRequest(
      name: json['name'] as String?,
      expiresInMinutes: json['expiresInMinutes'] as int? ?? 1440,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'expiresInMinutes': expiresInMinutes,
    };
  }
}

/// Extension methods for CreateSessionRequest
extension CreateSessionRequestExtension on CreateSessionRequest {
  /// Convert to map for API request
  Map<String, dynamic> toApiMap() {
    final map = <String, dynamic>{
      'expires_in_minutes': expiresInMinutes,
    };
    
    if (name != null && name!.isNotEmpty) {
      map['name'] = name;
    }
    
    return map;
  }

  /// Validate request
  bool get isValid {
    return expiresInMinutes > 0 && expiresInMinutes <= 10080; // Max 7 days
  }
}

/// Response model for creating a session
class CreateSessionResponse {
  final String sessionId;
  final String joinLink;
  final DateTime expiresAt;
  final String? name;

  const CreateSessionResponse({
    required this.sessionId,
    required this.joinLink,
    required this.expiresAt,
    this.name,
  });

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) {
    return CreateSessionResponse(
      sessionId: json['sessionId'] as String,
      joinLink: json['joinLink'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'joinLink': joinLink,
      'expiresAt': expiresAt.toIso8601String(),
      'name': name,
    };
  }
}

/// Extension methods for CreateSessionResponse
extension CreateSessionResponseExtension on CreateSessionResponse {
  /// Create from API response
  static CreateSessionResponse fromApiMap(Map<String, dynamic> map) {
    return CreateSessionResponse(
      sessionId: map['session_id'] as String,
      joinLink: map['join_link'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      name: map['name'] as String?,
    );
  }
}

/// Request model for joining a session
class JoinSessionRequest {
  final String displayName;
  final String? avatarColor;

  const JoinSessionRequest({
    required this.displayName,
    this.avatarColor,
  });

  factory JoinSessionRequest.fromJson(Map<String, dynamic> json) {
    return JoinSessionRequest(
      displayName: json['displayName'] as String,
      avatarColor: json['avatarColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'avatarColor': avatarColor,
    };
  }
}

/// Extension methods for JoinSessionRequest
extension JoinSessionRequestExtension on JoinSessionRequest {
  /// Convert to map for API request
  Map<String, dynamic> toApiMap() {
    final map = <String, dynamic>{
      'display_name': displayName,
    };
    
    if (avatarColor != null) {
      map['avatar_color'] = avatarColor;
    }
    
    return map;
  }

  /// Validate request
  bool get isValid {
    return displayName.trim().isNotEmpty && displayName.trim().length <= 30;
  }
}

/// Response model for joining a session
class JoinSessionResponse {
  final String userId;
  final String websocketToken;
  final String websocketUrl;

  const JoinSessionResponse({
    required this.userId,
    required this.websocketToken,
    required this.websocketUrl,
  });

  factory JoinSessionResponse.fromJson(Map<String, dynamic> json) {
    return JoinSessionResponse(
      userId: json['userId'] as String,
      websocketToken: json['websocketToken'] as String,
      websocketUrl: json['websocketUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'websocketToken': websocketToken,
      'websocketUrl': websocketUrl,
    };
  }
}

/// Extension methods for JoinSessionResponse
extension JoinSessionResponseExtension on JoinSessionResponse {
  /// Create from API response
  static JoinSessionResponse fromApiMap(Map<String, dynamic> map) {
    return JoinSessionResponse(
      userId: map['user_id'] as String,
      websocketToken: map['websocket_token'] as String,
      websocketUrl: map['websocket_url'] as String,
    );
  }
}

/// Current session state with participants
class SessionState {
  final Session? session;
  final ParticipantList participants;
  final String? currentUserId;
  final bool isLoading;
  final String? error;
  final SessionStatus status;

  const SessionState({
    this.session,
    this.participants = const ParticipantList(),
    this.currentUserId,
    this.isLoading = false,
    this.error,
    this.status = SessionStatus.disconnected,
  });

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      session: json['session'] != null 
          ? Session.fromJson(json['session'] as Map<String, dynamic>)
          : null,
      participants: json['participants'] != null
          ? ParticipantList.fromJson(json['participants'] as Map<String, dynamic>)
          : const ParticipantList(),
      currentUserId: json['currentUserId'] as String?,
      isLoading: json['isLoading'] as bool? ?? false,
      error: json['error'] as String?,
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.disconnected,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session': session?.toJson(),
      'participants': participants.toJson(),
      'currentUserId': currentUserId,
      'isLoading': isLoading,
      'error': error,
      'status': status.name,
    };
  }

  SessionState copyWith({
    Session? session,
    ParticipantList? participants,
    String? currentUserId,
    bool? isLoading,
    String? error,
    SessionStatus? status,
  }) {
    return SessionState(
      session: session ?? this.session,
      participants: participants ?? this.participants,
      currentUserId: currentUserId ?? this.currentUserId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionState &&
        other.session == session &&
        other.participants == participants &&
        other.currentUserId == currentUserId &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      session,
      participants,
      currentUserId,
      isLoading,
      error,
      status,
    );
  }

  @override
  String toString() {
    return 'SessionState(session: $session, status: $status, loading: $isLoading)';
  }
}

/// Enum for session connection status
enum SessionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Extension methods for SessionState
extension SessionStateExtension on SessionState {
  /// Check if user is in session
  bool get isInSession => session != null && currentUserId != null;

  /// Check if user is session creator
  bool get isCreator => 
      session != null && 
      currentUserId != null && 
      session!.isCreator(currentUserId!);

  /// Get current user participant
  Participant? get currentUser {
    if (currentUserId == null) return null;
    return participants.findById(currentUserId!);
  }

  /// Check if session is valid and active
  bool get isValidSession => session?.isValid ?? false;

  /// Get session display info
  String get sessionDisplayName => session?.displayName ?? 'Unknown Session';

  /// Copy with error
  SessionState withError(String error) {
    return copyWith(error: error, isLoading: false);
  }

  /// Copy with loading
  SessionState withLoading() {
    return copyWith(isLoading: true, error: null);
  }

  /// Copy with success
  SessionState withSuccess() {
    return copyWith(isLoading: false, error: null);
  }
}