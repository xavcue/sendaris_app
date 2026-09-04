import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/repositories/firebase_tracking_repository.dart';
import 'package:sendaris/features/tracking/data/services/tracking_remote_service.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';

void main() {
  group('FirebaseTrackingRepository', () {
    late FakeTrackingRemoteService service;
    late FirebaseTrackingRepository repository;

    setUp(() {
      service = FakeTrackingRemoteService();
      repository = FirebaseTrackingRepository(service);
    });

    test('persiste un perfil anónimo mediante el servicio remoto', () async {
      final profile = AnonymousTrackingProfile(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        createdAt: DateTime.utc(2026, 9, 3),
      );

      await repository.persistProfile(profile);

      expect(service.persistedProfiles, [profile]);
    });

    test('recupera perfiles remotos sin alterar sus datos', () async {
      final profile = AnonymousTrackingProfile(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        createdAt: DateTime.utc(2026, 9, 3),
      );

      service.profilesToRecover = [profile];

      final recovered = await repository.recoverProfiles();

      expect(recovered.length, 1);
      expect(recovered.first.anonymousId, profile.anonymousId);
      expect(recovered.first.createdAt, profile.createdAt);
      expect(recovered.first.isActive, profile.isActive);
    });

    test('convierte falta de sesión en un error controlado', () async {
      service.error = StateError('Internal authentication error');

      expect(
        repository.recoverProfiles,
        throwsA(
          isA<TrackingFailure>().having(
            (failure) => failure.message,
            'message',
            'Debes iniciar sesión antes de recuperar información.',
          ),
        ),
      );
    });

    test('no expone permission-denied de Firebase al usuario', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        repository.recoverProfiles,
        throwsA(
          isA<TrackingFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para recuperar esta información.',
          ),
        ),
      );
    });

    test('un error de red no se presenta como recuperación exitosa', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(
        repository.recoverProfiles,
        throwsA(
          isA<TrackingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });
  });
}

class FakeTrackingRemoteService implements TrackingRemoteService {
  final List<AnonymousTrackingProfile> persistedProfiles = [];

  List<AnonymousTrackingProfile> profilesToRecover = [];

  Object? error;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    persistedProfiles.add(profile);
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(profilesToRecover);
  }
}
