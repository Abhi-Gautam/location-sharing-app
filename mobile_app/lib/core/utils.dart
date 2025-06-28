import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

/// Utility functions for the application
class AppUtils {
  /// Generate a random avatar color from predefined colors
  static String generateRandomAvatarColor() {
    final random = Random();
    const colors = [
      '#FF5733', '#33A1FF', '#33FF57', '#FF33F1', '#FFD133',
      '#A133FF', '#33FFF1', '#FF8F33', '#8FFF33', '#3357FF',
    ];
    return colors[random.nextInt(colors.length)];
  }

  /// Convert hex color string to Color object
  static Color hexToColor(String hex) {
    try {
      final hexColor = hex.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
      return const Color(0xFFFF5733); // Default color
    } catch (e) {
      return const Color(0xFFFF5733); // Default color
    }
  }

  /// Convert Color object to hex string
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Validate session ID format
  static bool isValidSessionId(String sessionId) {
    return AppConstants.sessionIdRegex.hasMatch(sessionId);
  }

  /// Validate display name
  static String? validateDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Display name is required';
    }
    
    final trimmedName = name.trim();
    if (trimmedName.length < AppConstants.minDisplayNameLength) {
      return 'Display name must be at least ${AppConstants.minDisplayNameLength} characters';
    }
    
    if (trimmedName.length > AppConstants.maxDisplayNameLength) {
      return 'Display name must be less than ${AppConstants.maxDisplayNameLength} characters';
    }
    
    return null;
  }

  /// Validate session name
  static String? validateSessionName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return null; // Session name is optional
    }
    
    final trimmedName = name.trim();
    if (trimmedName.length > AppConstants.maxSessionNameLength) {
      return 'Session name must be less than ${AppConstants.maxSessionNameLength} characters';
    }
    
    return null;
  }

  /// Format duration in a human-readable way
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Format date time for display
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  /// Format time for display
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = lat1 * pi / 180;
    final double lat2Rad = lat2 * pi / 180;
    final double deltaLatRad = (lat2 - lat1) * pi / 180;
    final double deltaLonRad = (lon2 - lon1) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final kilometers = distanceInMeters / 1000;
      return '${kilometers.toStringAsFixed(1)}km';
    }
  }

  /// Generate initials from display name
  static String generateInitials(String displayName) {
    final words = displayName.trim().split(' ');
    if (words.isEmpty) return 'U';
    
    if (words.length == 1) {
      return words[0].substring(0, min(2, words[0].length)).toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Show error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show info snackbar
  static void showInfoSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Debounce function calls
  static Timer? _debounceTimer;
  static void debounce(Duration delay, VoidCallback action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, action);
  }

  /// Check if string is a valid URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Extract session ID from join link
  static String? extractSessionIdFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      final segments = uri.pathSegments;
      
      // Look for session ID in path segments
      for (final segment in segments) {
        if (isValidSessionId(segment)) {
          return segment;
        }
      }
      
      // Look for session ID in query parameters
      final sessionId = uri.queryParameters['session_id'] ?? 
                       uri.queryParameters['id'] ??
                       uri.queryParameters['s'];
      
      if (sessionId != null && isValidSessionId(sessionId)) {
        return sessionId;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate join link for session
  static String generateJoinLink(String sessionId, {String? baseUrl}) {
    final base = baseUrl ?? 'https://app.locationsharing.com';
    return '$base/join/$sessionId';
  }
}

/// Timer import for debounce function
import 'dart:async';