import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/app_config.dart';
import '../core/constants.dart';
import '../models/location.dart' as LocationModel;
import '../models/participant.dart';

/// Service for handling WebSocket real-time communication
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<WebSocketMessage>? _messageController;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  
  String? _sessionId;
  String? _userId;
  String? _token;
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  
  static const int _maxReconnectAttempts = 5;
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  /// Stream of incoming messages
  Stream<WebSocketMessage> get messages => _messageController?.stream ?? const Stream.empty();

  /// Connection status
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  /// Connect to WebSocket server
  Future<void> connect({
    required String sessionId,
    required String userId,
    required String token,
  }) async {
    if (_isConnecting || _isConnected) {
      return;
    }

    _sessionId = sessionId;
    _userId = userId;
    _token = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;

    await _connect();
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    await _cleanup();
  }

  /// Send location update
  void sendLocationUpdate(LocationModel.Location location) {
    if (!_isConnected) return;

    final message = WebSocketMessage(
      type: AppConstants.wsLocationUpdate,
      data: location.toApiMap(),
    );

    _sendMessage(message);
  }

  /// Send ping message
  void sendPing() {
    if (!_isConnected) return;

    final message = WebSocketMessage(
      type: AppConstants.wsPing,
      data: {},
    );

    _sendMessage(message);
  }

  /// Internal connection logic
  Future<void> _connect() async {
    try {
      _isConnecting = true;
      _messageController ??= StreamController<WebSocketMessage>.broadcast();

      // Build WebSocket URL based on backend type
      final wsUrl = _buildWebSocketUrl();
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Wait for connection to be established
      await _channel!.ready;
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Start ping timer
      _startPingTimer();

      // Emit connection event
      _emitMessage(WebSocketMessage(
        type: 'connected',
        data: {'sessionId': _sessionId, 'userId': _userId},
      ));

      print('WebSocket connected to $wsUrl');
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      
      _emitMessage(WebSocketMessage(
        type: 'error',
        data: {'message': 'Failed to connect: $e'},
      ));

      if (_shouldReconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// Build WebSocket URL based on configuration
  String _buildWebSocketUrl() {
    if (AppConfig.backendType == 'rust') {
      return '${AppConfig.wsBaseUrl}?token=$_token';
    } else {
      // Elixir Phoenix channels format
      return '${AppConfig.wsBaseUrl}?token=$_token&session_id=$_sessionId&user_id=$_userId';
    }
  }

  /// Handle incoming messages
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = WebSocketMessage.fromJson(json);
      
      // Handle pong messages internally
      if (message.type == AppConstants.wsPong) {
        return;
      }

      _emitMessage(message);
    } catch (e) {
      print('Error parsing WebSocket message: $e');
      _emitMessage(WebSocketMessage(
        type: 'error',
        data: {'message': 'Failed to parse message: $e'},
      ));
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    
    _emitMessage(WebSocketMessage(
      type: 'error',
      data: {'message': error.toString()},
    ));

    _isConnected = false;
    
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    print('WebSocket disconnected');
    
    _isConnected = false;
    _stopPingTimer();

    _emitMessage(WebSocketMessage(
      type: 'disconnected',
      data: {},
    ));

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  /// Send message to WebSocket
  void _sendMessage(WebSocketMessage message) {
    if (!_isConnected || _channel == null) return;

    try {
      final json = jsonEncode(message.toJson());
      _channel!.sink.add(json);
    } catch (e) {
      print('Error sending WebSocket message: $e');
    }
  }

  /// Emit message to listeners
  void _emitMessage(WebSocketMessage message) {
    if (_messageController != null && !_messageController!.isClosed) {
      _messageController!.add(message);
    }
  }

  /// Start ping timer
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) => sendPing());
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= _maxReconnectAttempts) {
      _emitMessage(WebSocketMessage(
        type: 'error',
        data: {'message': 'Max reconnection attempts reached'},
      ));
      return;
    }

    _reconnectAttempts++;
    
    _emitMessage(WebSocketMessage(
      type: 'reconnecting',
      data: {'attempt': _reconnectAttempts, 'maxAttempts': _maxReconnectAttempts},
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_shouldReconnect) {
        _connect();
      }
    });
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _isConnected = false;
    _isConnecting = false;
    
    _stopPingTimer();
    _reconnectTimer?.cancel();
    
    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }

    if (_messageController != null && !_messageController!.isClosed) {
      await _messageController!.close();
      _messageController = null;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    _shouldReconnect = false;
    await _cleanup();
  }
}

/// WebSocket message model
class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;

  const WebSocketMessage({
    required this.type,
    required this.data,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
    };
  }

  @override
  String toString() => 'WebSocketMessage(type: $type, data: $data)';
}

/// Extension methods for WebSocketMessage
extension WebSocketMessageExtension on WebSocketMessage {
  /// Check if message is a location update
  bool get isLocationUpdate => type == AppConstants.wsLocationUpdate;

  /// Check if message is participant joined
  bool get isParticipantJoined => type == AppConstants.wsParticipantJoined;

  /// Check if message is participant left
  bool get isParticipantLeft => type == AppConstants.wsParticipantLeft;

  /// Check if message is session ended
  bool get isSessionEnded => type == AppConstants.wsSessionEnded;

  /// Check if message is an error
  bool get isError => type == AppConstants.wsError;

  /// Get location from location update message
  LocationModel.Location? get location {
    if (!isLocationUpdate) return null;
    try {
      return LocationModel.Location(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(data['timestamp'] as String),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
        speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
        heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get participant from participant message
  Participant? get participant {
    if (!isParticipantJoined) return null;
    try {
      return ParticipantExtension.fromApiMap(data);
    } catch (e) {
      return null;
    }
  }

  /// Get user ID from participant left message
  String? get leftUserId {
    if (!isParticipantLeft) return null;
    return data['user_id'] as String?;
  }

  /// Get session end reason
  String? get sessionEndReason {
    if (!isSessionEnded) return null;
    return data['reason'] as String?;
  }

  /// Get error details
  WebSocketError? get error {
    if (!isError) return null;
    return WebSocketError(
      code: data['code'] as String? ?? AppConstants.errorUnknown,
      message: data['message'] as String? ?? 'Unknown error',
    );
  }
}

/// WebSocket error model
class WebSocketError {
  final String code;
  final String message;

  const WebSocketError({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'WebSocketError($code): $message';
}

/// WebSocket connection state
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket service extensions for reactive programming
extension WebSocketServiceExtension on WebSocketService {
  /// Get stream of location updates
  Stream<LocationModel.Location> get locationUpdates => messages
      .where((msg) => msg.isLocationUpdate)
      .map((msg) => msg.location!)
      .where((location) => location != null);

  /// Get stream of participant joined events
  Stream<Participant> get participantJoined => messages
      .where((msg) => msg.isParticipantJoined)
      .map((msg) => msg.participant!)
      .where((participant) => participant != null);

  /// Get stream of participant left events
  Stream<String> get participantLeft => messages
      .where((msg) => msg.isParticipantLeft)
      .map((msg) => msg.leftUserId!)
      .where((userId) => userId != null);

  /// Get stream of session ended events
  Stream<String> get sessionEnded => messages
      .where((msg) => msg.isSessionEnded)
      .map((msg) => msg.sessionEndReason ?? 'unknown');

  /// Get stream of connection errors
  Stream<WebSocketError> get errors => messages
      .where((msg) => msg.isError)
      .map((msg) => msg.error!)
      .where((error) => error != null);
}