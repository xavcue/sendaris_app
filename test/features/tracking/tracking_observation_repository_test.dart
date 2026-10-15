import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/repositories/firebase_tracking_repository.dart';
import 'package:sendaris/features/tracking/data/services/tracking_observation_remote_service.dart';
import 'package:sendaris/features/tracking/data/services/tracking_remote_service.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';

void main() {
  group('FirebaseTrackingRepository - observación', () {
    late _FakeObservationRemoteService service;
    late FirebaseTrackingRepository repository;

    setUp(() {
      service = _FakeObservationRemoteService();
      repository = FirebaseTrackingRepository(service);
    });

    test('recibe los perfiles emitidos por el servicio', () async {
      final profiles = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 10, 1),
          trackingNumber: 1,
        ),
      ];

      service.observationStream = Stream.value(profiles);

      final result = await repository.watchProfiles().first;

      expect(result, hasLength(1));
      expect(result.first.anonymousId, 'seguimiento-a');
      expect(result.first.trackingNumber, 1);
    });

    test('propaga nuevas actualizaciones de perfiles', () async {
      final first = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ];

      final second = [
        ...first,
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-b',
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      ];

      service.observationStream = Stream.fromIterable([first, second]);

      final results = await repository.watchProfiles().toList();

      expect(results, hasLength(2));
      expect(results.first, hasLength(1));
      expect(results.last, hasLength(2));
    });

    test('controla los errores de permisos de Firestore', () async {
      service.observationStream = Stream<List<AnonymousTrackingProfile>>.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      await expectLater(
        repository.watchProfiles(),
        emitsError(
          isA<TrackingFailure>().having(
            (failure) => failure.message,
            'mensaje',
            contains('No tienes autorización'),
          ),
        ),
      );
    });

    test('controla los cambios de contexto de autenticación', () async {
      service.observationStream = Stream<List<AnonymousTrackingProfile>>.error(
        StateError('Authentication changed.'),
      );

      await expectLater(
        repository.watchProfiles(),
        emitsError(
          isA<TrackingFailure>().having(
            (failure) => failure.message,
            'mensaje',
            contains('La sesión cambió'),
          ),
        ),
      );
    });

    test('rechaza servicios sin capacidad de observación', () async {
      final basicRepository = FirebaseTrackingRepository(
        _BasicTrackingRemoteService(),
      );

      await expectLater(
        basicRepository.watchProfiles(),
        emitsError(isA<TrackingFailure>()),
      );
    });
  });
}

class _FakeObservationRemoteService
    implements TrackingRemoteService, TrackingObservationRemoteService {
  Stream<List<AnonymousTrackingProfile>> observationStream =
      const Stream<List<AnonymousTrackingProfile>>.empty();

  @override
  Stream<List<AnonymousTrackingProfile>> watchProfiles() {
    return observationStream;
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}
}

class _BasicTrackingRemoteService implements TrackingRemoteService {
  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}
}
