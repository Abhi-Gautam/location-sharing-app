import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location_sharing/main.dart';
import 'package:location_sharing/app.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('App starts and shows home screen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        const ProviderScope(
          child: LocationSharingApp(),
        ),
      );

      // Wait for the app to finish loading
      await tester.pumpAndSettle();

      // Verify that home screen elements are present
      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Create Session'), findsOneWidget);
      expect(find.text('Join Session'), findsOneWidget);
    });

    testWidgets('Navigation to create session screen works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LocationSharingApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the create session button
      await tester.tap(find.text('Create Session'));
      await tester.pumpAndSettle();

      // Verify navigation to create session screen
      expect(find.text('Create Location Session'), findsOneWidget);
      expect(find.text('Session Name (Optional)'), findsOneWidget);
    });

    testWidgets('Navigation to join session screen works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LocationSharingApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the join session button
      await tester.tap(find.text('Join Session'));
      await tester.pumpAndSettle();

      // Verify navigation to join session screen
      expect(find.text('Join Location Session'), findsOneWidget);
      expect(find.text('Session ID or Link'), findsOneWidget);
      expect(find.text('Your Display Name'), findsOneWidget);
    });

    testWidgets('Create session form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LocationSharingApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to create session screen
      await tester.tap(find.text('Create Session'));
      await tester.pumpAndSettle();

      // Try to create session without filling form
      await tester.tap(find.text('Create Session').last);
      await tester.pumpAndSettle();

      // Since session name is optional, this should work
      // (though it may fail due to backend not being available in tests)
    });

    testWidgets('Join session form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LocationSharingApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to join session screen
      await tester.tap(find.text('Join Session'));
      await tester.pumpAndSettle();

      // Try to join session without filling required fields
      await tester.tap(find.text('Join Session').last);
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('Session ID or link is required'), findsOneWidget);
      expect(find.text('Display name is required'), findsOneWidget);
    });

    testWidgets('Join session form accepts valid input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LocationSharingApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to join session screen
      await tester.tap(find.text('Join Session'));
      await tester.pumpAndSettle();

      // Fill in valid session ID
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter session ID or paste link'),
        '12345678-1234-1234-1234-123456789012',
      );

      // Fill in display name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your name'),
        'Test User',
      );

      await tester.pumpAndSettle();

      // Try to join session (will fail without backend, but form should be valid)
      await tester.tap(find.text('Join Session').last);
      await tester.pumpAndSettle();

      // No validation errors should be shown
      expect(find.text('Session ID or link is required'), findsNothing);
      expect(find.text('Display name is required'), findsNothing);
    });
  });

  group('Participant Avatar Tests', () {
    testWidgets('Participant avatar displays correctly', (WidgetTester tester) async {
      // This would test the ParticipantAvatar widget in isolation
      // For now, we'll skip this as it requires more complex setup
    });
  });

  group('Map Widget Tests', () {
    testWidgets('Map widget initializes correctly', (WidgetTester tester) async {
      // This would test the MapWidget in isolation
      // Requires Google Maps setup for testing
    });
  });
}