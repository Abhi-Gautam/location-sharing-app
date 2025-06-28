import 'package:flutter_test/flutter_test.dart';
import 'package:location_sharing/core/utils.dart';
import 'package:location_sharing/models/session.dart';
import 'package:location_sharing/models/participant.dart';
import 'package:location_sharing/models/location.dart';

void main() {
  group('Utils Tests', () {
    test('generateRandomAvatarColor returns valid hex color', () {
      final color = AppUtils.generateRandomAvatarColor();
      expect(color, startsWith('#'));
      expect(color.length, equals(7));
    });

    test('hexToColor converts hex string to Color', () {
      final color = AppUtils.hexToColor('#FF5733');
      expect(color.value, equals(0xFFFF5733));
    });

    test('validateDisplayName works correctly', () {
      expect(AppUtils.validateDisplayName(''), equals('Display name is required'));
      expect(AppUtils.validateDisplayName('a'), equals('Display name must be at least 2 characters'));
      expect(AppUtils.validateDisplayName('Valid Name'), isNull);
      expect(AppUtils.validateDisplayName('Very Long Display Name That Exceeds Maximum Length'), isNotNull);
    });

    test('validateSessionName works correctly', () {
      expect(AppUtils.validateSessionName(''), isNull); // Optional field
      expect(AppUtils.validateSessionName('Valid Session'), isNull);
      expect(AppUtils.validateSessionName('Very Long Session Name That Exceeds Maximum Length'), isNotNull);
    });

    test('isValidSessionId validates UUID format', () {
      expect(AppUtils.isValidSessionId('12345678-1234-1234-1234-123456789012'), isTrue);
      expect(AppUtils.isValidSessionId('invalid-id'), isFalse);
      expect(AppUtils.isValidSessionId(''), isFalse);
    });

    test('calculateDistance calculates correct distance', () {
      final distance = AppUtils.calculateDistance(0, 0, 1, 1);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(200000)); // Should be reasonable distance
    });

    test('generateInitials creates correct initials', () {
      expect(AppUtils.generateInitials('John Doe'), equals('JD'));
      expect(AppUtils.generateInitials('SingleName'), equals('SI'));
      expect(AppUtils.generateInitials(''), equals('U'));
    });

    test('extractSessionIdFromLink extracts ID from various formats', () {
      expect(
        AppUtils.extractSessionIdFromLink('https://app.com/join/12345678-1234-1234-1234-123456789012'),
        equals('12345678-1234-1234-1234-123456789012'),
      );
      expect(
        AppUtils.extractSessionIdFromLink('12345678-1234-1234-1234-123456789012'),
        equals('12345678-1234-1234-1234-123456789012'),
      );
      expect(AppUtils.extractSessionIdFromLink('invalid-link'), isNull);
    });
  });

  group('Session Model Tests', () {
    test('Session creation and serialization', () {
      final now = DateTime.now();
      final session = Session(
        id: '12345678-1234-1234-1234-123456789012',
        name: 'Test Session',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        creatorId: 'creator-123',
        isActive: true,
        participantCount: 5,
      );

      expect(session.id, equals('12345678-1234-1234-1234-123456789012'));
      expect(session.name, equals('Test Session'));
      expect(session.isActive, isTrue);
      expect(session.participantCount, equals(5));

      // Test JSON serialization
      final json = session.toJson();
      final deserializedSession = Session.fromJson(json);
      expect(deserializedSession.id, equals(session.id));
      expect(deserializedSession.name, equals(session.name));
    });

    test('Session expiration logic', () {
      final pastTime = DateTime.now().subtract(const Duration(hours: 1));
      final futureTime = DateTime.now().add(const Duration(hours: 1));

      final expiredSession = Session(
        id: 'test',
        createdAt: pastTime,
        expiresAt: pastTime,
        creatorId: 'creator',
      );

      final activeSession = Session(
        id: 'test',
        createdAt: DateTime.now(),
        expiresAt: futureTime,
        creatorId: 'creator',
      );

      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.isValid, isFalse);
      expect(activeSession.isExpired, isFalse);
      expect(activeSession.isValid, isTrue);
    });

    test('CreateSessionRequest validation', () {
      const validRequest = CreateSessionRequest(
        name: 'Test Session',
        expiresInMinutes: 1440,
      );

      const invalidRequest = CreateSessionRequest(
        expiresInMinutes: 0, // Invalid duration
      );

      expect(validRequest.isValid, isTrue);
      expect(invalidRequest.isValid, isFalse);
    });
  });

  group('Participant Model Tests', () {
    test('Participant creation and status', () {
      final now = DateTime.now();
      final participant = Participant(
        userId: 'user-123',
        displayName: 'John Doe',
        avatarColor: '#FF5733',
        joinedAt: now.subtract(const Duration(minutes: 30)),
        lastSeen: now.subtract(const Duration(seconds: 10)),
        isActive: true,
      );

      expect(participant.userId, equals('user-123'));
      expect(participant.displayName, equals('John Doe'));
      expect(participant.initials, equals('JD'));
      expect(participant.isOnline, isTrue); // Last seen within 30 seconds
    });

    test('Participant online status calculation', () {
      final now = DateTime.now();
      
      final onlineParticipant = Participant(
        userId: 'user-1',
        displayName: 'Online User',
        avatarColor: '#FF5733',
        joinedAt: now,
        lastSeen: now.subtract(const Duration(seconds: 10)),
        isActive: true,
      );

      final offlineParticipant = Participant(
        userId: 'user-2',
        displayName: 'Offline User',
        avatarColor: '#FF5733',
        joinedAt: now,
        lastSeen: now.subtract(const Duration(minutes: 5)),
        isActive: true,
      );

      expect(onlineParticipant.isOnline, isTrue);
      expect(offlineParticipant.isOnline, isFalse);
    });

    test('ParticipantList operations', () {
      final participant1 = Participant(
        userId: 'user-1',
        displayName: 'User One',
        avatarColor: '#FF5733',
        joinedAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isActive: true,
      );

      final participant2 = Participant(
        userId: 'user-2',
        displayName: 'User Two',
        avatarColor: '#33FF57',
        joinedAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isActive: true,
      );

      var participantList = const ParticipantList();
      expect(participantList.count, equals(0));

      // Add participants
      participantList = participantList.addOrUpdate(participant1);
      participantList = participantList.addOrUpdate(participant2);
      expect(participantList.count, equals(2));

      // Find participant
      final foundParticipant = participantList.findById('user-1');
      expect(foundParticipant, isNotNull);
      expect(foundParticipant?.displayName, equals('User One'));

      // Remove participant
      participantList = participantList.remove('user-1');
      expect(participantList.count, equals(1));
      expect(participantList.findById('user-1'), isNull);
    });
  });

  group('Location Model Tests', () {
    test('Location creation and validation', () {
      final location = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
      );

      expect(location.latitude, equals(37.7749));
      expect(location.longitude, equals(-122.4194));
      expect(location.isValid, isTrue);

      // Test invalid coordinates
      final invalidLocation = Location(
        latitude: 100.0, // Invalid latitude
        longitude: -122.4194,
        timestamp: DateTime.now(),
      );

      expect(invalidLocation.isValid, isFalse);
    });

    test('Location distance calculation', () {
      final location1 = Location(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
      );

      final location2 = Location(
        latitude: 1.0,
        longitude: 1.0,
        timestamp: DateTime.now(),
      );

      final distance = location1.distanceTo(location2);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(200000)); // Should be reasonable distance
    });

    test('Location bounds calculation', () {
      final locations = [
        Location(latitude: 37.7749, longitude: -122.4194, timestamp: DateTime.now()),
        Location(latitude: 37.7849, longitude: -122.4094, timestamp: DateTime.now()),
        Location(latitude: 37.7649, longitude: -122.4294, timestamp: DateTime.now()),
      ];

      final bounds = LocationBoundsExtension.fromLocations(locations);
      expect(bounds, isNotNull);
      expect(bounds!.north, equals(37.7849));
      expect(bounds.south, equals(37.7649));
      expect(bounds.east, equals(-122.4094));
      expect(bounds.west, equals(-122.4294));
    });

    test('Location API serialization', () {
      final location = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.parse('2023-01-01T00:00:00Z'),
        accuracy: 5.0,
      );

      final apiMap = location.toApiMap();
      expect(apiMap['lat'], equals(37.7749));
      expect(apiMap['lng'], equals(-122.4194));
      expect(apiMap['accuracy'], equals(5.0));

      final deserializedLocation = LocationExtension.fromApiMap(apiMap);
      expect(deserializedLocation.latitude, equals(location.latitude));
      expect(deserializedLocation.longitude, equals(location.longitude));
    });
  });
}