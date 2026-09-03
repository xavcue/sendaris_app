import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/services/uuid_anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';

void main() {
  group('Anonimización del seguimiento', () {
    test('genera identificadores UUID v4 válidos y diferentes', () {
      final generator = UuidAnonymousIdGenerator();

      final firstId = generator.generate();
      final secondId = generator.generate();

      final uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-'
        r'[0-9a-f]{4}-'
        r'4[0-9a-f]{3}-'
        r'[89ab][0-9a-f]{3}-'
        r'[0-9a-f]{12}$',
        caseSensitive: false,
      );

      expect(uuidV4Pattern.hasMatch(firstId), isTrue);
      expect(uuidV4Pattern.hasMatch(secondId), isTrue);
      expect(firstId, isNot(equals(secondId)));
    });

    test('crea un perfil únicamente con información anónima', () {
      final factory = AnonymousTrackingProfileFactory(
        UuidAnonymousIdGenerator(),
      );

      final profile = factory.create(createdAt: DateTime.utc(2026, 9, 2));

      expect(profile.anonymousId, isNotEmpty);
      expect(profile.createdAt, DateTime.utc(2026, 9, 2));
      expect(profile.isActive, isTrue);
    });
  });
}
