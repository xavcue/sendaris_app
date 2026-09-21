import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('TrackingViewModel', () {
    late FakeTrackingRepository repository;
    late TrackingViewModel viewModel;

    setUp(() {
      repository = FakeTrackingRepository();

      viewModel = TrackingViewModel(
        repository,
        AnonymousTrackingProfileFactory(FakeAnonymousIdGenerator()),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('crea y persiste el primer seguimiento con número estable', () async {
      final success = await viewModel.createAndPersistProfile();

      expect(success, true);

      expect(repository.persistedProfiles.length, 1);

      expect(
        repository.persistedProfiles.first.anonymousId,
        '550e8400-e29b-41d4-a716-446655440000',
      );

      expect(repository.persistedProfiles.first.trackingNumber, 1);

      expect(viewModel.activeTrackingLabel, 'Seguimiento 1');

      expect(viewModel.errorMessage, isNull);
    });

    test('crea el siguiente número después del mayor existente', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 9, 3),
          trackingNumber: 1,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-b',
          createdAt: DateTime.utc(2026, 9, 10),
          trackingNumber: 2,
        ),
      ];

      await viewModel.recoverProfiles();

      final success = await viewModel.createAndPersistProfile();

      expect(success, true);

      expect(viewModel.activeTrackingLabel, 'Seguimiento 3');

      expect(repository.persistedProfiles.last.trackingNumber, 3);
    });

    test(
      'recupera seguimientos persistidos sin alterar su identificador',
      () async {
        repository.profilesToRecover = [
          AnonymousTrackingProfile(
            anonymousId: '550e8400-e29b-41d4-a716-446655440000',
            createdAt: DateTime.utc(2026, 9, 3),
            trackingNumber: 1,
          ),
        ];

        final success = await viewModel.recoverProfiles();

        expect(success, true);

        expect(viewModel.profiles.length, 1);

        expect(
          viewModel.profiles.first.anonymousId,
          '550e8400-e29b-41d4-a716-446655440000',
        );

        expect(viewModel.activeTrackingLabel, 'Seguimiento 1');
      },
    );

    test('selecciona otro seguimiento sin mezclar identificadores', () async {
      final first = AnonymousTrackingProfile(
        anonymousId: 'seguimiento-a',
        createdAt: DateTime.utc(2026, 9, 3),
        trackingNumber: 1,
      );

      final second = AnonymousTrackingProfile(
        anonymousId: 'seguimiento-b',
        createdAt: DateTime.utc(2026, 9, 10),
        trackingNumber: 2,
      );

      repository.profilesToRecover = [first, second];

      await viewModel.recoverProfiles();

      expect(viewModel.activeAnonymousId, 'seguimiento-a');

      final selected = viewModel.selectProfile(second);

      expect(selected, true);

      expect(viewModel.activeAnonymousId, 'seguimiento-b');

      expect(viewModel.activeTrackingLabel, 'Seguimiento 2');
    });

    test('elimina definitivamente un seguimiento', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 9, 3),
          trackingNumber: 1,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-b',
          createdAt: DateTime.utc(2026, 9, 10),
          trackingNumber: 2,
        ),
      ];

      await viewModel.recoverProfiles();

      final success = await viewModel.deleteProfiles({'seguimiento-b'});

      expect(success, true);

      expect(repository.deletedAnonymousIds, ['seguimiento-b']);

      expect(viewModel.profiles.length, 1);

      expect(viewModel.activeAnonymousId, 'seguimiento-a');

      expect(
        viewModel.successMessage,
        'Seguimiento eliminado definitivamente.',
      );
    });

    test('permite eliminar varios seguimientos', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 9, 3),
          trackingNumber: 1,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-b',
          createdAt: DateTime.utc(2026, 9, 10),
          trackingNumber: 2,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-c',
          createdAt: DateTime.utc(2026, 9, 20),
          trackingNumber: 3,
        ),
      ];

      await viewModel.recoverProfiles();

      final success = await viewModel.deleteProfiles({
        'seguimiento-b',
        'seguimiento-c',
      });

      expect(success, true);

      expect(repository.deletedAnonymousIds.toSet(), {
        'seguimiento-b',
        'seguimiento-c',
      });

      expect(viewModel.profiles.length, 1);

      expect(viewModel.activeTrackingLabel, 'Seguimiento 1');
    });

    test('permite eliminar todos los seguimientos', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 9, 3),
          trackingNumber: 1,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-b',
          createdAt: DateTime.utc(2026, 9, 10),
          trackingNumber: 2,
        ),
      ];

      await viewModel.recoverProfiles();

      final success = await viewModel.deleteProfiles({
        'seguimiento-a',
        'seguimiento-b',
      });

      expect(success, true);

      expect(viewModel.profiles, isEmpty);

      expect(viewModel.activeProfile, isNull);

      expect(viewModel.activeAnonymousId, isNull);

      expect(viewModel.hasProfiles, false);
    });

    test(
      'si elimina el seguimiento seleccionado cambia al siguiente disponible',
      () async {
        final first = AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 9, 3),
          trackingNumber: 1,
        );

        final second = AnonymousTrackingProfile(
          anonymousId: 'seguimiento-b',
          createdAt: DateTime.utc(2026, 9, 10),
          trackingNumber: 2,
        );

        repository.profilesToRecover = [first, second];

        await viewModel.recoverProfiles();

        viewModel.selectProfile(second);

        expect(viewModel.activeTrackingLabel, 'Seguimiento 2');

        final success = await viewModel.deleteProfiles({'seguimiento-b'});

        expect(success, true);

        expect(viewModel.activeAnonymousId, 'seguimiento-a');

        expect(viewModel.activeTrackingLabel, 'Seguimiento 1');
      },
    );

    test(
      'la numeración existente no cambia al eliminar un seguimiento intermedio',
      () async {
        repository.profilesToRecover = [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-a',
            createdAt: DateTime.utc(2026, 9, 3),
            trackingNumber: 1,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-b',
            createdAt: DateTime.utc(2026, 9, 10),
            trackingNumber: 2,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-c',
            createdAt: DateTime.utc(2026, 9, 20),
            trackingNumber: 3,
          ),
        ];

        await viewModel.recoverProfiles();

        await viewModel.deleteProfiles({'seguimiento-b'});

        expect(
          viewModel.trackingLabelFor(viewModel.orderedProfiles[0]),
          'Seguimiento 1',
        );

        expect(
          viewModel.trackingLabelFor(viewModel.orderedProfiles[1]),
          'Seguimiento 3',
        );
      },
    );

    test('un error de eliminación conserva el seguimiento local', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-a',
          createdAt: DateTime.utc(2026, 9, 3),
          trackingNumber: 1,
        ),
      ];

      await viewModel.recoverProfiles();

      repository.deletionFailure = const TrackingFailure(
        'No fue posible eliminar el seguimiento.',
      );

      final success = await viewModel.deleteProfiles({'seguimiento-a'});

      expect(success, false);

      expect(viewModel.profiles.length, 1);

      expect(viewModel.activeAnonymousId, 'seguimiento-a');

      expect(viewModel.errorMessage, 'No fue posible eliminar el seguimiento.');
    });

    test('un error de recuperación se presenta de forma controlada', () async {
      repository.recoveryFailure = const TrackingFailure(
        'No fue posible recuperar la información de forma segura.',
      );

      final success = await viewModel.recoverProfiles();

      expect(success, false);

      expect(viewModel.profiles, isEmpty);

      expect(
        viewModel.errorMessage,
        'No fue posible recuperar la información de forma segura.',
      );
    });
  });
}

class FakeTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  final List<AnonymousTrackingProfile> persistedProfiles = [];

  final List<String> deletedAnonymousIds = [];

  List<AnonymousTrackingProfile> profilesToRecover = [];

  TrackingFailure? recoveryFailure;
  TrackingFailure? deletionFailure;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {
    persistedProfiles.add(profile);
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List.unmodifiable(profilesToRecover);
  }

  @override
  Future<void> deleteProfile(String anonymousId) async {
    final failure = deletionFailure;

    if (failure != null) {
      throw failure;
    }

    deletedAnonymousIds.add(anonymousId);
  }
}

class FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  @override
  String generate() {
    return '550e8400-e29b-41d4-a716-446655440000';
  }
}
