import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/mappers/anonymous_tracking_profile_mapper.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';

void main() {
  group('AnonymousTrackingProfileMapper', () {
    test('persiste únicamente los campos permitidos', () {
      final profile = AnonymousTrackingProfile(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        createdAt: DateTime.utc(2026, 9, 2, 20),
      );

      final data = AnonymousTrackingProfileMapper.toFirestore(profile);

      expect(
        data.keys.toSet(),
        equals(AnonymousTrackingProfileMapper.allowedFields),
      );

      expect(data.containsKey('idAnonimo'), isFalse);
      expect(data.containsKey('nombre'), isFalse);
      expect(data.containsKey('apellido'), isFalse);
      expect(data.containsKey('cedula'), isFalse);
      expect(data.containsKey('fotografia'), isFalse);
      expect(data.containsKey('direccion'), isFalse);
      expect(data.containsKey('fechaNacimiento'), isFalse);
      expect(data.containsKey('historiaClinica'), isFalse);

      expect(data['activo'], isTrue);
      expect(data['fechaCreacion'], isA<Timestamp>());
    });

    test('reconstruye un perfil anónimo válido desde Firestore', () {
      final data = <String, dynamic>{
        'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 2, 20)),
        'activo': true,
      };

      final profile = AnonymousTrackingProfileMapper.fromFirestore(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        data: data,
      );

      expect(profile.anonymousId, '550e8400-e29b-41d4-a716-446655440000');
      expect(profile.createdAt, DateTime.utc(2026, 9, 2, 20));
      expect(profile.isActive, isTrue);
    });

    test('rechaza una fecha de creación inválida', () {
      final data = <String, dynamic>{
        'fechaCreacion': '2026-09-02',
        'activo': true,
      };

      expect(
        () => AnonymousTrackingProfileMapper.fromFirestore(
          anonymousId: '550e8400-e29b-41d4-a716-446655440000',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
