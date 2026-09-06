import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  test('recupera y selecciona un seguimiento activo existente', () async {
    final existing = AnonymousTrackingProfile(
      anonymousId: 'anonimo-existente',
      createdAt: DateTime.utc(2026, 9, 5),
    );

    final repository = _FakeTrackingRepository(recoveredProfiles: [existing]);

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final success = await viewModel.initialize();

    expect(success, true);

    expect(viewModel.activeAnonymousId, 'anonimo-existente');

    expect(repository.persistedProfiles, isEmpty);
  });

  test('crea un seguimiento si la recuperación válida está vacía', () async {
    final repository = _FakeTrackingRepository();

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final success = await viewModel.initialize();

    expect(success, true);

    expect(viewModel.activeAnonymousId, 'anonimo-generado');

    expect(repository.persistedProfiles.length, 1);
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

  test('ignora seguimientos inactivos y selecciona uno activo', () async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-inactivo',
          createdAt: DateTime.utc(2026, 9, 4),
          isActive: false,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-activo',
          createdAt: DateTime.utc(2026, 9, 5),
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    await viewModel.initialize();

    expect(viewModel.activeAnonymousId, 'anonimo-activo');
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
