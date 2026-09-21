import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/repositories/firebase_tracking_repository.dart';
import 'package:sendaris/features/tracking/data/services/tracking_deletion_remote_service.dart';
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

    test(
      'persiste un seguimiento anónimo mediante el servicio remoto',
      () async {
        final profile = AnonymousTrackingProfile(
          anonymousId: '550e8400-e29b-41d4-a716-446655440000',
          createdAt: DateTime.utc(2026, 9, 3),
        );

        await repository.persistProfile(profile);

        expect(service.persistedProfiles, [profile]);
      },
    );

    test('recupera seguimientos remotos sin alterar sus datos', () async {
      final profile = AnonymousTrackingProfile(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        createdAt: DateTime.utc(2026, 9, 3),
        trackingNumber: 1,
      );

      service.profilesToRecover = [profile];

      final recovered = await repository.recoverProfiles();

      expect(recovered.length, 1);

      expect(recovered.first.anonymousId, profile.anonymousId);

      expect(recovered.first.createdAt, profile.createdAt);

      expect(recovered.first.trackingNumber, 1);

      expect(recovered.first.isActive, profile.isActive);
    });

    test(
      'elimina permanentemente un seguimiento mediante el servicio remoto',
      () async {
        await repository.deleteProfile('seguimiento-a');

        expect(service.deletedAnonymousIds, ['seguimiento-a']);
      },
    );

    test(
      'convierte falta de sesión al eliminar en un mensaje comprensible',
      () async {
        service.error = StateError('Internal authentication error');

        expect(
          () => repository.deleteProfile('seguimiento-a'),
          throwsA(
            isA<TrackingFailure>().having(
              (failure) => failure.message,
              'message',
              'Debes iniciar sesión antes de eliminar el seguimiento.',
            ),
          ),
        );
      },
    );

    test(
      'un error de red al eliminar utiliza un mensaje comprensible',
      () async {
        service.error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );

        expect(
          () => repository.deleteProfile('seguimiento-a'),
          throwsA(
            isA<TrackingFailure>().having(
              (failure) => failure.message,
              'message',
              'No fue posible eliminar el seguimiento. '
                  'Verifica tu conexión.',
            ),
          ),
        );
      },
    );

    test(
      'convierte falta de sesión en un mensaje orientado al usuario',
      () async {
        service.error = StateError('Internal authentication error');

        expect(
          repository.recoverProfiles,
          throwsA(
            isA<TrackingFailure>().having(
              (failure) => failure.message,
              'message',
              'Debes iniciar sesión antes de cargar la información.',
            ),
          ),
        );
      },
    );

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
            'No tienes autorización para consultar esta información.',
          ),
        ),
      );
    });

    test('un error de red utiliza un mensaje comprensible', () async {
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
            'No fue posible cargar la información. '
                'Verifica tu conexión.',
          ),
        ),
      );
    });

    test(
      'un error de guardado por red no utiliza terminología remota',
      () async {
        service.error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );

        expect(
          () => repository.persistProfile(
            AnonymousTrackingProfile(
              anonymousId: '550e8400-e29b-41d4-a716-446655440000',
              createdAt: DateTime.utc(2026, 9, 3),
            ),
          ),
          throwsA(
            isA<TrackingFailure>().having(
              (failure) => failure.message,
              'message',
              'No fue posible guardar la información. '
                  'Verifica tu conexión.',
            ),
          ),
        );
      },
    );
  });
}

class FakeTrackingRemoteService
    implements TrackingRemoteService, TrackingDeletionRemoteService {
  final List<AnonymousTrackingProfile> persistedProfiles = [];

  final List<String> deletedAnonymousIds = [];

  List<AnonymousTrackingProfile> profilesToRecover = [];

  Object? error;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {
    _throwIfNeeded();

    persistedProfiles.add(profile);
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    _throwIfNeeded();

    return List.unmodifiable(profilesToRecover);
  }

  @override
  Future<void> deleteProfile(String anonymousId) async {
    _throwIfNeeded();

    deletedAnonymousIds.add(anonymousId);
  }

  void _throwIfNeeded() {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }
  }
}
