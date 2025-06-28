import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../models/session.dart';
import '../models/participant.dart';
import '../models/location.dart';
import '../core/utils.dart';

/// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Provider for storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

/// Session state provider
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(
    ref.read(apiServiceProvider),
    ref.read(webSocketServiceProvider),
    ref.read(storageServiceProvider),
  );
});

/// Session state notifier
class SessionNotifier extends StateNotifier<SessionState> {
  final ApiService _apiService;
  final WebSocketService _webSocketService;
  final StorageService _storageService;
  
  StreamSubscription<WebSocketMessage>? _wsSubscription;
  Timer? _autoSaveTimer;
  
  SessionNotifier(
    this._apiService,
    this._webSocketService,
    this._storageService,
  ) : super(const SessionState()) {
    _initializeFromStorage();
    _startAutoSave();
  }

  /// Initialize session state from storage
  Future<void> _initializeFromStorage() async {
    try {
      final savedSession = await _storageService.getCurrentSession();
      if (savedSession != null && savedSession.isValidSession) {
        state = savedSession;
        // Try to reconnect if we have session data
        if (state.session != null && state.currentUserId != null) {
          await _reconnectWebSocket();
        }
      }
    } catch (e) {
      print('Error loading session from storage: $e');
    }
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveToStorage();
    });
  }

  /// Save current state to storage
  Future<void> _saveToStorage() async {
    try {
      if (state.isInSession) {
        await _storageService.saveCurrentSession(state);
      }
    } catch (e) {
      print('Error saving session to storage: $e');
    }
  }

  /// Create a new session
  Future<void> createSession({
    String? name,
    int expiresInMinutes = 1440,
  }) async {
    try {
      state = state.withLoading();

      final request = CreateSessionRequest(
        name: name,
        expiresInMinutes: expiresInMinutes,
      );

      final response = await _apiService.createSession(request);
      
      final session = Session(
        id: response.sessionId,
        name: response.name,
        createdAt: DateTime.now(),
        expiresAt: response.expiresAt,
        creatorId: '', // Will be set when joining
        isActive: true,
      );

      state = state.copyWith(
        session: session,
        isLoading: false,
        error: null,
      );

      // Save to recent sessions
      await _storageService.saveRecentSession(session);
      await _saveToStorage();
    } on ApiException catch (e) {
      state = state.withError(e.message);
    } catch (e) {
      state = state.withError('Failed to create session: $e');
    }
  }

  /// Join a session
  Future<void> joinSession({
    required String sessionId,
    required String displayName,
    String? avatarColor,
  }) async {
    try {
      state = state.withLoading();

      // First, get session details
      final session = await _apiService.getSession(sessionId);
      
      if (!session.isValid) {
        throw const ApiException('INVALID_SESSION', 'Session has expired or is inactive');
      }

      // Join the session
      final request = JoinSessionRequest(
        displayName: displayName,
        avatarColor: avatarColor ?? AppUtils.generateRandomAvatarColor(),
      );

      final response = await _apiService.joinSession(sessionId, request);

      // Save user profile
      await _storageService.saveUserProfile(
        userId: response.userId,
        displayName: displayName,
        avatarColor: request.avatarColor!,
      );

      // Update state
      state = state.copyWith(
        session: session,
        currentUserId: response.userId,
        isLoading: false,
        error: null,
        status: SessionStatus.connecting,
      );

      // Connect WebSocket
      await _connectWebSocket(
        sessionId: sessionId,
        userId: response.userId,
        token: response.websocketToken,
      );

      // Load participants
      await _loadParticipants();

      // Save to recent sessions
      await _storageService.saveRecentSession(session);
      await _saveToStorage();
    } on ApiException catch (e) {
      state = state.withError(e.message);
    } catch (e) {
      state = state.withError('Failed to join session: $e');
    }
  }

  /// Leave current session
  Future<void> leaveSession() async {
    try {
      if (state.session != null && state.currentUserId != null) {
        await _apiService.leaveSession(state.session!.id, state.currentUserId!);
      }
    } catch (e) {
      print('Error leaving session: $e');
    } finally {
      await _cleanup();
    }
  }

  /// End session (creator only)
  Future<void> endSession() async {
    try {
      if (state.session != null && state.isCreator) {
        state = state.withLoading();
        await _apiService.endSession(state.session!.id);
      }
    } on ApiException catch (e) {
      state = state.withError(e.message);
    } catch (e) {
      state = state.withError('Failed to end session: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Load session participants
  Future<void> _loadParticipants() async {
    try {
      if (state.session == null) return;

      final participants = await _apiService.getSessionParticipants(state.session!.id);
      final participantList = ParticipantList(participants: participants);

      state = state.copyWith(participants: participantList);
    } catch (e) {
      print('Error loading participants: $e');
    }
  }

  /// Connect WebSocket
  Future<void> _connectWebSocket({
    required String sessionId,
    required String userId,
    required String token,
  }) async {
    try {
      await _webSocketService.connect(
        sessionId: sessionId,
        userId: userId,
        token: token,
      );

      // Listen to WebSocket messages
      _wsSubscription = _webSocketService.messages.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print('WebSocket error: $error');
          state = state.copyWith(status: SessionStatus.error);
        },
      );

      state = state.copyWith(status: SessionStatus.connected);
    } catch (e) {
      state = state.copyWith(status: SessionStatus.error);
      throw e;
    }
  }

  /// Reconnect WebSocket (for app resume)
  Future<void> _reconnectWebSocket() async {
    if (state.session == null || state.currentUserId == null) return;

    try {
      state = state.copyWith(status: SessionStatus.reconnecting);
      
      // We need the token from storage or re-join
      // For now, let's assume we can reconnect without re-joining
      // In a real app, you might need to store the token
      
      await _loadParticipants();
      state = state.copyWith(status: SessionStatus.connected);
    } catch (e) {
      state = state.copyWith(status: SessionStatus.error);
    }
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'connected':
        state = state.copyWith(status: SessionStatus.connected);
        break;

      case 'disconnected':
        state = state.copyWith(status: SessionStatus.disconnected);
        break;

      case 'reconnecting':
        state = state.copyWith(status: SessionStatus.reconnecting);
        break;

      case 'participant_joined':
        _handleParticipantJoined(message);
        break;

      case 'participant_left':
        _handleParticipantLeft(message);
        break;

      case 'location_update':
        _handleLocationUpdate(message);
        break;

      case 'session_ended':
        _handleSessionEnded(message);
        break;

      case 'error':
        _handleWebSocketError(message);
        break;
    }
  }

  /// Handle participant joined
  void _handleParticipantJoined(WebSocketMessage message) {
    try {
      final participant = message.participant;
      if (participant != null) {
        final updatedParticipants = state.participants.addOrUpdate(participant);
        state = state.copyWith(participants: updatedParticipants);
      }
    } catch (e) {
      print('Error handling participant joined: $e');
    }
  }

  /// Handle participant left
  void _handleParticipantLeft(WebSocketMessage message) {
    try {
      final userId = message.leftUserId;
      if (userId != null) {
        final updatedParticipants = state.participants.remove(userId);
        state = state.copyWith(participants: updatedParticipants);
      }
    } catch (e) {
      print('Error handling participant left: $e');
    }
  }

  /// Handle location update
  void _handleLocationUpdate(WebSocketMessage message) {
    try {
      final userId = message.data['user_id'] as String?;
      final location = message.location;
      
      if (userId != null && location != null) {
        final updatedParticipants = state.participants.updateLocation(userId, location);
        state = state.copyWith(participants: updatedParticipants);
      }
    } catch (e) {
      print('Error handling location update: $e');
    }
  }

  /// Handle session ended
  void _handleSessionEnded(WebSocketMessage message) {
    final reason = message.sessionEndReason ?? 'unknown';
    print('Session ended: $reason');
    _cleanup();
  }

  /// Handle WebSocket error
  void _handleWebSocketError(WebSocketMessage message) {
    final error = message.error;
    if (error != null) {
      state = state.copyWith(
        status: SessionStatus.error,
        error: error.message,
      );
    }
  }

  /// Send location update
  void sendLocationUpdate(Location location) {
    if (state.status == SessionStatus.connected) {
      _webSocketService.sendLocationUpdate(location);
    }
  }

  /// Update participant location locally (for current user)
  void updateCurrentUserLocation(Location location) {
    if (state.currentUserId != null) {
      final updatedParticipants = state.participants.updateLocation(
        state.currentUserId!,
        location,
      );
      state = state.copyWith(participants: updatedParticipants);
    }
  }

  /// Cleanup session data
  Future<void> _cleanup() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;

    await _webSocketService.disconnect();

    state = const SessionState();
    
    await _storageService.clearCurrentSession();
  }

  /// Refresh session data
  Future<void> refresh() async {
    if (state.session == null) return;

    try {
      final session = await _apiService.getSession(state.session!.id);
      await _loadParticipants();
      
      state = state.copyWith(
        session: session,
        error: null,
      );
    } catch (e) {
      print('Error refreshing session: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _wsSubscription?.cancel();
    _webSocketService.dispose();
    _apiService.dispose();
    super.dispose();
  }
}

/// Provider for session creation state
final sessionCreationProvider = StateNotifierProvider<SessionCreationNotifier, SessionCreationState>((ref) {
  return SessionCreationNotifier(ref.read(apiServiceProvider));
});

/// Session creation state
class SessionCreationState {
  final bool isLoading;
  final String? error;
  final CreateSessionResponse? response;

  const SessionCreationState({
    this.isLoading = false,
    this.error,
    this.response,
  });

  SessionCreationState copyWith({
    bool? isLoading,
    String? error,
    CreateSessionResponse? response,
  }) {
    return SessionCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      response: response ?? this.response,
    );
  }
}

/// Session creation notifier
class SessionCreationNotifier extends StateNotifier<SessionCreationState> {
  final ApiService _apiService;

  SessionCreationNotifier(this._apiService) : super(const SessionCreationState());

  /// Create session
  Future<void> createSession({
    String? name,
    int expiresInMinutes = 1440,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final request = CreateSessionRequest(
        name: name,
        expiresInMinutes: expiresInMinutes,
      );

      final response = await _apiService.createSession(request);
      
      state = state.copyWith(
        isLoading: false,
        response: response,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create session: $e',
      );
    }
  }

  /// Reset state
  void reset() {
    state = const SessionCreationState();
  }
}

/// Provider for recent sessions
final recentSessionsProvider = FutureProvider<List<Session>>((ref) async {
  final storage = ref.read(storageServiceProvider);
  return storage.getRecentSessions();
});

/// Provider for current user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final storage = ref.read(storageServiceProvider);
  return storage.getUserProfile();
});