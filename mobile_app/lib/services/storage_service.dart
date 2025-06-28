import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/session.dart';
import '../models/participant.dart';

/// Service for local data persistence using SharedPreferences
class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  /// Singleton instance
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// Initialize the service
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure preferences are initialized
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // User Data Methods

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.storageKeyUserId, userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.storageKeyUserId);
  }

  /// Save display name
  Future<void> saveDisplayName(String displayName) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.storageKeyDisplayName, displayName);
  }

  /// Get display name
  Future<String?> getDisplayName() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.storageKeyDisplayName);
  }

  /// Save avatar color
  Future<void> saveAvatarColor(String color) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.storageKeyAvatarColor, color);
  }

  /// Get avatar color
  Future<String?> getAvatarColor() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.storageKeyAvatarColor);
  }

  // Session Data Methods

  /// Save current session
  Future<void> saveCurrentSession(SessionState sessionState) async {
    final prefs = await _preferences;
    final json = jsonEncode(sessionState.toJson());
    await prefs.setString(AppConstants.storageKeyCurrentSession, json);
  }

  /// Get current session
  Future<SessionState?> getCurrentSession() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(AppConstants.storageKeyCurrentSession);
      
      if (json == null) return null;
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      return SessionState.fromJson(data);
    } catch (e) {
      print('Error loading session from storage: $e');
      return null;
    }
  }

  /// Clear current session
  Future<void> clearCurrentSession() async {
    final prefs = await _preferences;
    await prefs.remove(AppConstants.storageKeyCurrentSession);
  }

  // Backend Configuration Methods

  /// Save backend type
  Future<void> saveBackendType(String backendType) async {
    final prefs = await _preferences;
    await prefs.setString(AppConstants.storageKeyBackendType, backendType);
  }

  /// Get backend type
  Future<String?> getBackendType() async {
    final prefs = await _preferences;
    return prefs.getString(AppConstants.storageKeyBackendType);
  }

  // Recent Sessions Methods

  /// Save recent session
  Future<void> saveRecentSession(Session session) async {
    final recentSessions = await getRecentSessions();
    
    // Remove if already exists
    recentSessions.removeWhere((s) => s.id == session.id);
    
    // Add to beginning
    recentSessions.insert(0, session);
    
    // Keep only last 10 sessions
    if (recentSessions.length > 10) {
      recentSessions.removeRange(10, recentSessions.length);
    }
    
    await _saveRecentSessions(recentSessions);
  }

  /// Get recent sessions
  Future<List<Session>> getRecentSessions() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString('recent_sessions');
      
      if (json == null) return [];
      
      final data = jsonDecode(json) as List<dynamic>;
      return data
          .map((item) => Session.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading recent sessions: $e');
      return [];
    }
  }

  /// Save recent sessions list
  Future<void> _saveRecentSessions(List<Session> sessions) async {
    final prefs = await _preferences;
    final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString('recent_sessions', json);
  }

  /// Clear recent sessions
  Future<void> clearRecentSessions() async {
    final prefs = await _preferences;
    await prefs.remove('recent_sessions');
  }

  // User Preferences Methods

  /// Save boolean preference
  Future<void> saveBool(String key, bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(key, value);
  }

  /// Get boolean preference
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await _preferences;
    return prefs.getBool(key) ?? defaultValue;
  }

  /// Save string preference
  Future<void> saveString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  /// Get string preference
  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  /// Save integer preference
  Future<void> saveInt(String key, int value) async {
    final prefs = await _preferences;
    await prefs.setInt(key, value);
  }

  /// Get integer preference
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final prefs = await _preferences;
    return prefs.getInt(key) ?? defaultValue;
  }

  /// Save double preference
  Future<void> saveDouble(String key, double value) async {
    final prefs = await _preferences;
    await prefs.setDouble(key, value);
  }

  /// Get double preference
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final prefs = await _preferences;
    return prefs.getDouble(key) ?? defaultValue;
  }

  // Utility Methods

  /// Check if key exists
  Future<bool> hasKey(String key) async {
    final prefs = await _preferences;
    return prefs.containsKey(key);
  }

  /// Remove key
  Future<void> removeKey(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }

  /// Get all keys
  Future<Set<String>> getAllKeys() async {
    final prefs = await _preferences;
    return prefs.getKeys();
  }

  /// Clear all data
  Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.clear();
  }

  // App State Methods

  /// Save last app version
  Future<void> saveAppVersion(String version) async {
    await saveString('app_version', version);
  }

  /// Get last app version
  Future<String?> getAppVersion() async {
    return getString('app_version');
  }

  /// Save first launch flag
  Future<void> setFirstLaunch(bool isFirst) async {
    await saveBool('is_first_launch', isFirst);
  }

  /// Check if this is first launch
  Future<bool> isFirstLaunch() async {
    return getBool('is_first_launch', defaultValue: true);
  }

  /// Save onboarding completed flag
  Future<void> setOnboardingCompleted(bool completed) async {
    await saveBool('onboarding_completed', completed);
  }

  /// Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async {
    return getBool('onboarding_completed', defaultValue: false);
  }

  // Debug Methods

  /// Get storage size estimate
  Future<Map<String, dynamic>> getStorageInfo() async {
    final prefs = await _preferences;
    final keys = prefs.getKeys();
    
    int totalSize = 0;
    final keyInfo = <String, dynamic>{};
    
    for (final key in keys) {
      final value = prefs.get(key);
      final size = _estimateSize(value);
      totalSize += size;
      keyInfo[key] = {
        'type': value.runtimeType.toString(),
        'size': size,
      };
    }
    
    return {
      'totalKeys': keys.length,
      'estimatedSize': totalSize,
      'keys': keyInfo,
    };
  }

  /// Estimate size of stored value
  int _estimateSize(dynamic value) {
    if (value is String) {
      return value.length * 2; // UTF-16 encoding
    } else if (value is bool) {
      return 1;
    } else if (value is int) {
      return 8;
    } else if (value is double) {
      return 8;
    } else {
      return 0;
    }
  }

  /// Export all data as JSON
  Future<Map<String, dynamic>> exportData() async {
    final prefs = await _preferences;
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};
    
    for (final key in keys) {
      data[key] = prefs.get(key);
    }
    
    return data;
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    final prefs = await _preferences;
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    }
  }
}

/// Storage service helper methods
extension StorageServiceHelper on StorageService {
  /// Save user profile data
  Future<void> saveUserProfile({
    required String userId,
    required String displayName,
    required String avatarColor,
  }) async {
    await Future.wait([
      saveUserId(userId),
      saveDisplayName(displayName),
      saveAvatarColor(avatarColor),
    ]);
  }

  /// Get user profile data
  Future<UserProfile?> getUserProfile() async {
    final results = await Future.wait([
      getUserId(),
      getDisplayName(),
      getAvatarColor(),
    ]);
    
    final userId = results[0] as String?;
    final displayName = results[1] as String?;
    final avatarColor = results[2] as String?;
    
    if (userId == null || displayName == null) {
      return null;
    }
    
    return UserProfile(
      userId: userId,
      displayName: displayName,
      avatarColor: avatarColor ?? AppConstants.defaultAvatarColor,
    );
  }

  /// Clear user data
  Future<void> clearUserData() async {
    await Future.wait([
      removeKey(AppConstants.storageKeyUserId),
      removeKey(AppConstants.storageKeyDisplayName),
      removeKey(AppConstants.storageKeyAvatarColor),
      clearCurrentSession(),
    ]);
  }
}

/// User profile data model
class UserProfile {
  final String userId;
  final String displayName;
  final String avatarColor;

  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.avatarColor,
  });

  @override
  String toString() {
    return 'UserProfile(userId: $userId, displayName: $displayName, avatarColor: $avatarColor)';
  }
}