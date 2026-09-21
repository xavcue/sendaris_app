import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  test('recupera y selecciona un seguimiento existente numerado', () async {
    final existing = AnonymousTrackingProfile(
      anonymousId: 'anonimo-existente',
      createdAt: DateTime.utc(2026, 9, 5),
      trackingNumber: 1,
    );

    final repository = _FakeTrackingRepository(recoveredProfiles: [existing]);

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final success = await viewModel.initialize();

    expect(success, true);

    expect(viewModel.activeAnonymousId, 'anonimo-existente');

    expect(viewModel.activeTrackingLabel, 'Seguimiento 1');

    expect(repository.persistedProfiles, isEmpty);
  });

  test(
    'no crea automáticamente un seguimiento cuando no existe ninguno',
    () async {
      final repository = _FakeTrackingRepository();

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      final success = await viewModel.initialize();

      expect(success, true);

      expect(viewModel.isInitialized, true);

      expect(viewModel.profiles, isEmpty);

      expect(viewModel.activeProfile, isNull);

      expect(viewModel.activeAnonymousId, isNull);

      expect(repository.persistedProfiles, isEmpty);
    },
  );

  test('migra seguimientos anteriores asignando numeración estable', () async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-dos',
          createdAt: DateTime.utc(2026, 9, 10),
        ),
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-uno',
          createdAt: DateTime.utc(2026, 9, 5),
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final success = await viewModel.initialize();

    expect(success, true);

    expect(viewModel.profiles.length, 2);

    expect(
      viewModel.trackingLabelFor(viewModel.orderedProfiles[0]),
      'Seguimiento 1',
    );

    expect(
      viewModel.trackingLabelFor(viewModel.orderedProfiles[1]),
      'Seguimiento 2',
    );

    expect(repository.persistedProfiles.length, 2);

    expect(repository.persistedProfiles[0].trackingNumber, 1);

    expect(repository.persistedProfiles[1].trackingNumber, 2);
  });

  test('no crea un seguimiento nuevo si falla la recuperación', () async {
    final repository = _FakeTrackingRepository(
      recoveryFailure: const TrackingFailure('Error remoto controlado.'),
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final success = await viewModel.initialize();

    expect(success, false);

    expect(repository.persistedProfiles, isEmpty);

    expect(viewModel.activeProfile, isNull);
  });

  test('ignora internamente seguimientos inactivos heredados y selecciona uno activo', () async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-inactivo',
          createdAt: DateTime.utc(2026, 9, 4),
          trackingNumber: 1,
          isActive: false,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-activo',
          createdAt: DateTime.utc(2026, 9, 5),
          trackingNumber: 2,
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    await viewModel.initialize();

    expect(viewModel.activeAnonymousId, 'anonimo-activo');

    expect(viewModel.activeTrackingLabel, 'Seguimiento 2');
  });
}

class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({
    this.recoveredProfiles = const [],
    this.recoveryFailure,
  });

  final List<AnonymousTrackingProfile> recoveredProfiles;

  final TrackingFailure? recoveryFailure;

  final List<AnonymousTrackingProfile> persistedProfiles = [];

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

    return List.unmodifiable(recoveredProfiles);
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'anonimo-generado';
  }
}
