import 'package:flutter/material.dart';

/// Extensions for String class
extension StringExtensions on String {
  /// Check if string is empty or null
  bool get isEmptyOrNull => isEmpty;

  /// Capitalize first letter of string
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Title case - capitalize first letter of each word
  String get titleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty ? word : word.capitalize)
        .join(' ');
  }

  /// Remove extra whitespace
  String get cleanWhitespace {
    return trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

/// Extensions for DateTime class
extension DateTimeExtensions on DateTime {
  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && 
           month == yesterday.month && 
           day == yesterday.day;
  }

  /// Get relative time string (e.g., "2 minutes ago", "1 hour ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Extensions for Duration class
extension DurationExtensions on Duration {
  /// Format duration as "2h 30m" or "45m"
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get human readable format
  String get humanReadable {
    if (inDays > 0) {
      return '${inDays} day${inDays == 1 ? '' : 's'}';
    } else if (inHours > 0) {
      return '${inHours} hour${inHours == 1 ? '' : 's'}';
    } else if (inMinutes > 0) {
      return '${inMinutes} minute${inMinutes == 1 ? '' : 's'}';
    } else {
      return '${inSeconds} second${inSeconds == 1 ? '' : 's'}';
    }
  }
}

/// Extensions for double class (for coordinates)
extension CoordinateExtensions on double {
  /// Format coordinate for display (e.g., "37.7749°")
  String get formatCoordinate {
    return '${toStringAsFixed(4)}°';
  }

  /// Convert to degrees, minutes, seconds format
  String toDMS(bool isLatitude) {
    final degrees = truncate().abs();
    final minutes = ((abs() - degrees) * 60).truncate();
    final seconds = (((abs() - degrees) * 60 - minutes) * 60);
    
    final direction = isLatitude 
        ? (this >= 0 ? 'N' : 'S')
        : (this >= 0 ? 'E' : 'W');
    
    return '$degrees°${minutes}\'${seconds.toStringAsFixed(1)}"$direction';
  }
}

/// Extensions for Color class
extension ColorExtensions on Color {
  /// Convert to hex string
  String get toHex {
    return '#${value.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Get contrasting color (black or white) for text on this background
  Color get contrastingColor {
    final luminance = computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Lighten color by percentage
  Color lighten(double percentage) {
    assert(percentage >= 0 && percentage <= 1);
    
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness + percentage).clamp(0.0, 1.0);
    
    return hsl.withLightness(lightness).toColor();
  }

  /// Darken color by percentage
  Color darken(double percentage) {
    assert(percentage >= 0 && percentage <= 1);
    
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - percentage).clamp(0.0, 1.0);
    
    return hsl.withLightness(lightness).toColor();
  }
}

/// Extensions for BuildContext
extension BuildContextExtensions on BuildContext {
  /// Get screen size
  Size get screenSize => MediaQuery.of(this).size;
  
  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;
  
  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;
  
  /// Check if device is tablet
  bool get isTablet => screenWidth > 600;
  
  /// Check if device is phone
  bool get isPhone => !isTablet;
  
  /// Get theme
  ThemeData get theme => Theme.of(this);
  
  /// Get color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  /// Get text theme
  TextTheme get textTheme => Theme.of(this).textTheme;
  
  /// Show snackbar with message
  void showSnackbar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  /// Navigate to page
  Future<T?> push<T>(Widget page) {
    return Navigator.of(this).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }
  
  /// Navigate and replace current page
  Future<T?> pushReplacement<T extends Object?>(Widget page) {
    return Navigator.of(this).pushReplacement<T, T>(
      MaterialPageRoute(builder: (_) => page),
    );
  }
  
  /// Pop current page
  void pop<T>([T? result]) {
    Navigator.of(this).pop(result);
  }
}

/// Extensions for List class
extension ListExtensions<T> on List<T> {
  /// Get element at index or null if out of bounds
  T? getOrNull(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }

  /// Check if list is empty or null
  bool get isEmptyOrNull => isEmpty;

  /// Get first element or null if empty
  T? get firstOrNull => isEmptyOrNull ? null : first;

  /// Get last element or null if empty
  T? get lastOrNull => isEmptyOrNull ? null : last;
}

