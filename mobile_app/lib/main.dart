import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'services/storage_service.dart';
import 'app.dart';

void main() async {
  // Ensure widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  await StorageService.initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Print app configuration in debug mode
  if (AppConfig.isDebugMode) {
    debugPrint('App Configuration:');
    AppConfig.toMap().forEach((key, value) {
      debugPrint('  $key: $value');
    });
  }

  // Validate configuration
  if (!AppConfig.isValid()) {
    debugPrint('WARNING: Invalid app configuration detected!');
  }

  runApp(
    ProviderScope(
      child: LocationSharingApp(),
    ),
  );
}