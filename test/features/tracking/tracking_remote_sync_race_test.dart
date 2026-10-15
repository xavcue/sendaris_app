import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_observation_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  late _ConcurrentTrackingRepository repository;
  late TrackingViewModel viewModel;

  setUp(() {
    repository = _ConcurrentTrackingRepository();

    viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FixedAnonymousIdGenerator()),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await repository.dispose();
  });

  group('TrackingViewModel - concurrencia de sincronización', () {
    test(
      'una actualización antigua no elimina un seguimiento recién creado',
      () async {
        repository.recoveredProfiles = [];

        viewModel.synchronizeAuthenticationContext('uid-a');

        expect(await viewModel.initialize(), isTrue);
        expect(repository.observations, hasLength(1));

        final pendingWrite = Completer<void>();
        repository.pendingPersist = pendingWrite;

        final creation = viewModel.createAndPersistProfile();

        expect(viewModel.isLoading, isTrue);

        // La escucha entrega una instantánea anterior
        // a la confirmación de la creación.
        repository.emit(0, []);

        pendingWrite.complete();

        expect(await creation, isTrue);

        expect(
          viewModel.profiles.map((profile) => profile.anonymousId),
          contains('nuevo-seguimiento'),
        );

        expect(viewModel.activeAnonymousId, 'nuevo-seguimiento');
      },
    );

    test(
      'una actualización antigua no restaura un seguimiento eliminado',
      () async {
        final initialProfile = _profile('seguimiento-eliminado', 1);

        repository.recoveredProfiles = [initialProfile];

        viewModel.synchronizeAuthenticationContext('uid-a');

        expect(await viewModel.initialize(), isTrue);
        expect(repository.observations, hasLength(1));

        final pendingDeletion = Completer<void>();
        repository.pendingDelete = pendingDeletion;

        final deletion = viewModel.deleteProfiles({'seguimiento-eliminado'});

        expect(viewModel.isLoading, isTrue);

        // Firestore entrega una instantánea antigua
        // mientras el borrado todavía está pendiente.
        repository.emit(0, [initialProfile]);

        pendingDeletion.complete();

        expect(await deletion, isTrue);

        expect(viewModel.profiles, isEmpty);
        expect(viewModel.activeAnonymousId, isNull);
      },
    );

    test(
      'cancela la escucha anterior y crea otra para la nueva cuenta',
      () async {
        repository.recoveredProfiles = [_profile('perfil-a', 1)];

        viewModel.synchronizeAuthenticationContext('uid-a');

        expect(await viewModel.initialize(), isTrue);

        expect(repository.observations, hasLength(1));

        final previousObservation = repository.observations.first;

        expect(previousObservation.hasListener, isTrue);

        viewModel.synchronizeAuthenticationContext('uid-b');

        // Permite completar las cancelaciones asíncronas.
        await Future<void>.delayed(Duration.zero);

        expect(previousObservation.hasListener, isFalse);
        expect(viewModel.profiles, isEmpty);

        repository.recoveredProfiles = [_profile('perfil-b', 1)];

        expect(await viewModel.initialize(), isTrue);

        expect(repository.observations, hasLength(2));
        expect(repository.observations.last.hasListener, isTrue);

        expect(viewModel.activeAnonymousId, 'perfil-b');
      },
    );
  });
}

AnonymousTrackingProfile _profile(String anonymousId, int trackingNumber) {
  return AnonymousTrackingProfile(
    anonymousId: anonymousId,
    createdAt: DateTime.utc(2026, 10, trackingNumber),
    trackingNumber: trackingNumber,
  );
}

class _ConcurrentTrackingRepository
    implements
        TrackingRepository,
        TrackingDeletionRepository,
        TrackingObservationRepository {
  List<AnonymousTrackingProfile> recoveredProfiles = [];

  Completer<void>? pendingPersist;
  Completer<void>? pendingDelete;

  final List<StreamController<List<AnonymousTrackingProfile>>> observations =
      [];

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List<AnonymousTrackingProfile>.from(recoveredProfiles);
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) {
    return pendingPersist?.future ?? Future<void>.value();
  }

  @override
  Future<void> deleteProfile(String anonymousId) {
    return pendingDelete?.future ?? Future<void>.value();
  }

  @override
  Stream<List<AnonymousTrackingProfile>> watchProfiles() {
    final controller =
        StreamController<List<AnonymousTrackingProfile>>.broadcast(sync: true);

    observations.add(controller);

    return controller.stream;
  }

  void emit(int index, List<AnonymousTrackingProfile> profiles) {
    observations[index].add(profiles);
  }

  Future<void> dispose() async {
    for (final controller in observations) {
      await controller.close();
    }
  }
}

class _FixedAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FixedAnonymousIdGenerator();

  @override
  String generate() => 'nuevo-seguimiento';
}
