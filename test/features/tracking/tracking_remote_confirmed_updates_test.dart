import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_observation_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  late _ConfirmedUpdatesRepository repository;
  late TrackingViewModel viewModel;

  setUp(() {
    repository = _ConfirmedUpdatesRepository();

    viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FixedAnonymousIdGenerator()),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await repository.dispose();
  });

  group('TrackingViewModel - actualizaciones confirmadas', () {
    test('refleja una eliminación remota posterior a una creación', () async {
      repository.recoveredProfiles = [];

      viewModel.synchronizeAuthenticationContext('uid-a');

      expect(await viewModel.initialize(), isTrue);
      expect(repository.observationCalls, 1);

      expect(await viewModel.createAndPersistProfile(), isTrue);

      expect(viewModel.activeAnonymousId, 'nuevo-seguimiento');

      // Representa una eliminación legítima confirmada
      // por el servidor después de la creación local.
      repository.emit([]);

      expect(viewModel.profiles, isEmpty);
      expect(viewModel.activeAnonymousId, isNull);
    });

    test('refleja una recreación remota posterior a un borrado', () async {
      final profile = _profile('seguimiento-recreado', 1);

      repository.recoveredProfiles = [profile];

      viewModel.synchronizeAuthenticationContext('uid-a');

      expect(await viewModel.initialize(), isTrue);

      expect(await viewModel.deleteProfiles({'seguimiento-recreado'}), isTrue);

      expect(viewModel.profiles, isEmpty);

      // Otro dispositivo recrea el documento y el servicio
      // entrega una actualización confirmada.
      repository.emit([profile]);

      expect(viewModel.profiles, hasLength(1));
      expect(viewModel.activeAnonymousId, 'seguimiento-recreado');
    });

    test('recupera la observación después de un error', () async {
      repository.recoveredProfiles = [_profile('seguimiento-1', 1)];

      viewModel.synchronizeAuthenticationContext('uid-a');

      expect(await viewModel.initialize(), isTrue);
      expect(repository.observationCalls, 1);

      repository.emitError(
        const TrackingFailure('No fue posible consultar Firestore.'),
      );

      expect(viewModel.errorMessage, 'No fue posible consultar Firestore.');

      repository.recoveredProfiles = [
        _profile('seguimiento-1', 1),
        _profile('seguimiento-2', 2),
      ];

      expect(await viewModel.recoverProfiles(), isTrue);

      expect(repository.observationCalls, 2);

      repository.emit([
        _profile('seguimiento-1', 1),
        _profile('seguimiento-2', 2),
        _profile('seguimiento-3', 3),
      ]);

      expect(viewModel.profiles, hasLength(3));
    });
  });
}

AnonymousTrackingProfile _profile(String anonymousId, int trackingNumber) {
  return AnonymousTrackingProfile(
    anonymousId: anonymousId,
    createdAt: DateTime.utc(2026, 10, trackingNumber),
    trackingNumber: trackingNumber,
  );
}

class _ConfirmedUpdatesRepository
    implements
        TrackingRepository,
        TrackingDeletionRepository,
        TrackingObservationRepository {
  final StreamController<List<AnonymousTrackingProfile>> _controller =
      StreamController<List<AnonymousTrackingProfile>>.broadcast(sync: true);

  List<AnonymousTrackingProfile> recoveredProfiles = [];

  int observationCalls = 0;

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List<AnonymousTrackingProfile>.from(recoveredProfiles);
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<void> deleteProfile(String anonymousId) async {}

  @override
  Stream<List<AnonymousTrackingProfile>> watchProfiles() {
    observationCalls++;
    return _controller.stream;
  }

  void emit(List<AnonymousTrackingProfile> profiles) {
    _controller.add(profiles);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FixedAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FixedAnonymousIdGenerator();

  @override
  String generate() => 'nuevo-seguimiento';
}
