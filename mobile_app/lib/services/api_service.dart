import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../core/constants.dart';
import '../models/session.dart';
import '../models/participant.dart';

/// Service for handling REST API calls
class ApiService {
  late final Dio _dio;
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      sendTimeout: AppConstants.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors for debugging in development
    if (AppConfig.isDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
      ));
    }

    // Add error handling interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final apiError = _handleDioError(error);
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: apiError,
          type: DioExceptionType.unknown,
        ));
      },
    ));
  }

  /// Create a new session
  Future<CreateSessionResponse> createSession(CreateSessionRequest request) async {
    try {
      final response = await _dio.post('/sessions', data: request.toApiMap());
      return CreateSessionResponseExtension.fromApiMap(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(AppConstants.errorUnknown, 'Failed to create session: $e');
    }
  }

  /// Get session details by ID
  Future<Session> getSession(String sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId');
      return SessionExtension.fromApiMap(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(AppConstants.errorUnknown, 'Failed to get session: $e');
    }
  }

  /// Join a session
  Future<JoinSessionResponse> joinSession(String sessionId, JoinSessionRequest request) async {
    try {
      final response = await _dio.post('/sessions/$sessionId/join', data: request.toApiMap());
      return JoinSessionResponseExtension.fromApiMap(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(AppConstants.errorUnknown, 'Failed to join session: $e');
    }
  }

  /// Leave a session
  Future<void> leaveSession(String sessionId, String userId) async {
    try {
      await _dio.delete('/sessions/$sessionId/participants/$userId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(AppConstants.errorUnknown, 'Failed to leave session: $e');
    }
  }

  /// Get session participants
  Future<List<Participant>> getSessionParticipants(String sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId/participants');
      final data = response.data as Map<String, dynamic>;
      final participantsList = data['participants'] as List<dynamic>;
      
      return participantsList
          .map((p) => ParticipantExtension.fromApiMap(p as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(AppConstants.errorUnknown, 'Failed to get participants: $e');
    }
  }

  /// End a session (creator only)
  Future<void> endSession(String sessionId) async {
    try {
      await _dio.delete('/sessions/$sessionId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(AppConstants.errorUnknown, 'Failed to end session: $e');
    }
  }

  /// Health check endpoint
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Handle Dio errors and convert to API exceptions
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          AppConstants.errorNetworkError,
          'Connection timeout. Please check your internet connection.',
        );
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final data = error.response?.data;
        
        if (data is Map<String, dynamic>) {
          final errorCode = data['code'] as String? ?? AppConstants.errorUnknown;
          final message = data['message'] as String? ?? 'Unknown error occurred';
          return ApiException(errorCode, message);
        }
        
        return ApiException(
          _getErrorCodeForStatusCode(statusCode),
          _getErrorMessageForStatusCode(statusCode),
        );
      
      case DioExceptionType.cancel:
        return ApiException(AppConstants.errorUnknown, 'Request was cancelled');
      
      case DioExceptionType.unknown:
      default:
        return ApiException(
          AppConstants.errorNetworkError,
          'Network error. Please check your internet connection.',
        );
    }
  }

  String _getErrorCodeForStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'BAD_REQUEST';
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return AppConstants.errorInvalidSession;
      case 409:
        return AppConstants.errorSessionFull;
      case 422:
        return 'VALIDATION_ERROR';
      case 500:
        return 'INTERNAL_SERVER_ERROR';
      case 503:
        return 'SERVICE_UNAVAILABLE';
      default:
        return AppConstants.errorUnknown;
    }
  }

  String _getErrorMessageForStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication required.';
      case 403:
        return 'Access forbidden.';
      case 404:
        return 'Session not found or has expired.';
      case 409:
        return 'Session is full. Cannot join.';
      case 422:
        return 'Invalid input. Please check your data.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service temporarily unavailable.';
      default:
        return 'An unexpected error occurred.';
    }
  }

  /// Close the Dio client
  void dispose() {
    _dio.close();
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String code;
  final String message;

  const ApiException(this.code, this.message);

  factory ApiException.fromDioError(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    final data = error.response?.data;
    
    if (data is Map<String, dynamic>) {
      final errorCode = data['code'] as String? ?? AppConstants.errorUnknown;
      final message = data['message'] as String? ?? 'Unknown error occurred';
      return ApiException(errorCode, message);
    }
    
    return ApiException(
      AppConstants.errorNetworkError,
      'Network error occurred',
    );
  }

  @override
  String toString() => 'ApiException($code): $message';

  /// Check if error is due to network issues
  bool get isNetworkError => code == AppConstants.errorNetworkError;

  /// Check if error is due to invalid session
  bool get isInvalidSession => code == AppConstants.errorInvalidSession;

  /// Check if error is due to session being full
  bool get isSessionFull => code == AppConstants.errorSessionFull;

  /// Check if error is retryable
  bool get isRetryable => [
    AppConstants.errorNetworkError,
    'INTERNAL_SERVER_ERROR',
    'SERVICE_UNAVAILABLE',
  ].contains(code);
}

/// API response wrapper for handling success/error states
class ApiResponse<T> {
  final T? data;
  final ApiException? error;
  final bool isSuccess;

  const ApiResponse.success(this.data) 
      : error = null, 
        isSuccess = true;

  const ApiResponse.error(this.error) 
      : data = null, 
        isSuccess = false;

  /// Create from async operation
  static Future<ApiResponse<T>> fromFuture<T>(Future<T> future) async {
    try {
      final result = await future;
      return ApiResponse.success(result);
    } on ApiException catch (e) {
      return ApiResponse.error(e);
    } catch (e) {
      return ApiResponse.error(
        ApiException(AppConstants.errorUnknown, e.toString()),
      );
    }
  }

  /// Map the data if successful
  ApiResponse<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      try {
        return ApiResponse.success(mapper(data!));
      } catch (e) {
        return ApiResponse.error(
          ApiException(AppConstants.errorUnknown, e.toString()),
        );
      }
    }
    return ApiResponse.error(error ?? ApiException(AppConstants.errorUnknown, 'No data'));
  }

  /// Fold the response into a single value
  R fold<R>(
    R Function(ApiException error) onError,
    R Function(T data) onSuccess,
  ) {
    if (isSuccess && data != null) {
      return onSuccess(data!);
    }
    return onError(error ?? ApiException(AppConstants.errorUnknown, 'No data'));
  }
}