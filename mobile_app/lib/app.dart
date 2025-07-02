import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'core/utils.dart';
import 'models/session.dart';
import 'providers/session_provider.dart';
import 'providers/location_provider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';

/// Main application widget
class LocationSharingApp extends ConsumerWidget {
  const LocationSharingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: AppConfig.isDebugMode,
      home: const AppRouter(),
      builder: (context, child) {
        // Global error handling
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return ErrorScreen(error: details.exception.toString());
        };
        
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// App router that determines which screen to show
class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final locationState = ref.watch(locationProvider);

    // Listen to session state changes for navigation
    ref.listen<SessionState>(sessionProvider, (previous, current) {
      if (previous?.isInSession == false && current.isInSession) {
        // Navigated into session - start location tracking if permitted
        _handleSessionJoined(ref);
      } else if (previous?.isInSession == true && !current.isInSession) {
        // Left session - stop location tracking
        _handleSessionLeft(ref);
      }
    });

    // Show map screen if in session, otherwise show home screen
    if (sessionState.isInSession) {
      return const MapScreen();
    } else {
      return const HomeScreen();
    }
  }

  /// Handle session joined
  void _handleSessionJoined(WidgetRef ref) {
    final locationController = ref.read(locationTrackingControllerProvider);
    
    // Start location sharing when joining session
    Future.microtask(() async {
      try {
        await locationController.startLocationSharing();
      } catch (e) {
        debugPrint('Error starting location sharing: $e');
      }
    });
  }

  /// Handle session left
  void _handleSessionLeft(WidgetRef ref) {
    final locationController = ref.read(locationTrackingControllerProvider);
    
    // Stop location sharing when leaving session
    Future.microtask(() async {
      try {
        await locationController.stopLocationSharing();
      } catch (e) {
        debugPrint('Error stopping location sharing: $e');
      }
    });
  }
}

/// Global error screen
class ErrorScreen extends StatelessWidget {
  final String error;
  
  const ErrorScreen({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We encountered an unexpected error. Please try restarting the app.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (AppConfig.isDebugMode) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Details:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      error,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: () {
                // Restart the app (simplified approach)
                runApp(
                  ProviderScope(
                    child: LocationSharingApp(),
                  ),
                );
              },
              child: const Text('Restart App'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splash screen widget
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    // Navigate to main app after splash
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppRouter()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  size: 64,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConfig.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share your location in real-time',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App lifecycle handler
class AppLifecycleHandler extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleHandler({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends ConsumerState<AppLifecycleHandler>
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning between states
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS 17+)
        break;
    }
  }

  void _handleAppResumed() {
    // Refresh location permissions and services
    final locationNotifier = ref.read(locationProvider.notifier);
    locationNotifier.refresh();

    // Reconnect WebSocket if needed
    final sessionState = ref.read(sessionProvider);
    if (sessionState.isInSession && sessionState.status == SessionStatus.disconnected) {
      // Try to reconnect
      // This would typically involve re-joining the session
    }
  }

  void _handleAppPaused() {
    // App is going to background
    // Location tracking continues in background if permission is granted
  }

  void _handleAppDetached() {
    // App is being terminated
    final sessionNotifier = ref.read(sessionProvider.notifier);
    final locationNotifier = ref.read(locationProvider.notifier);
    
    // Cleanup resources
    sessionNotifier.dispose();
    locationNotifier.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Global snackbar provider for showing messages
final globalSnackbarProvider = StateNotifierProvider<GlobalSnackbarNotifier, String?>((ref) {
  return GlobalSnackbarNotifier();
});

/// Global snackbar notifier
class GlobalSnackbarNotifier extends StateNotifier<String?> {
  GlobalSnackbarNotifier() : super(null);

  void showError(String message) {
    state = 'error:$message';
    Future.delayed(const Duration(milliseconds: 100), () {
      state = null;
    });
  }

  void showSuccess(String message) {
    state = 'success:$message';
    Future.delayed(const Duration(milliseconds: 100), () {
      state = null;
    });
  }

  void showInfo(String message) {
    state = 'info:$message';
    Future.delayed(const Duration(milliseconds: 100), () {
      state = null;
    });
  }
}

/// Global snackbar listener widget
class GlobalSnackbarListener extends ConsumerWidget {
  final Widget child;

  const GlobalSnackbarListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(globalSnackbarProvider, (previous, current) {
      if (current != null) {
        final parts = current.split(':');
        if (parts.length == 2) {
          final type = parts[0];
          final message = parts[1];

          switch (type) {
            case 'error':
              AppUtils.showErrorSnackbar(context, message);
              break;
            case 'success':
              AppUtils.showSuccessSnackbar(context, message);
              break;
            case 'info':
              AppUtils.showInfoSnackbar(context, message);
              break;
          }
        }
      }
    });

    return child;
  }
}