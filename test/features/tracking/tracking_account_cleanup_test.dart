import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('TrackingViewModel limpieza de cuenta', () {
    late _AccountCleanupTrackingRepository repository;

    late TrackingViewModel viewModel;

    setUp(() {
      repository = _AccountCleanupTrackingRepository();

      viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test(
      'recupera del servidor y elimina todos los seguimientos de la cuenta',
      () async {
        repository.profilesToRecover = [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-1',
            createdAt: DateTime.utc(2026, 10, 1),
            trackingNumber: 1,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-2',
            createdAt: DateTime.utc(2026, 10, 2),
            trackingNumber: 2,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-3',
            createdAt: DateTime.utc(2026, 10, 3),
            trackingNumber: 3,
          ),
        ];

        final result = await viewModel.deleteAllProfilesForAccount();

        expect(result, isTrue);

        expect(repository.recoverCalls, 1);

        expect(repository.deletedIds, [
          'seguimiento-1',
          'seguimiento-2',
          'seguimiento-3',
        ]);

        expect(viewModel.profiles, isEmpty);

        expect(viewModel.activeProfile, isNull);

        expect(viewModel.activeAnonymousId, isNull);

        expect(
          viewModel.successMessage,
          'Datos de la cuenta eliminados correctamente.',
        );
      },
    );

    test('también finaliza cuando la cuenta no tiene seguimientos', () async {
      repository.profilesToRecover = const [];

      final result = await viewModel.deleteAllProfilesForAccount();

      expect(result, isTrue);

      expect(repository.recoverCalls, 1);

      expect(repository.deletedIds, isEmpty);

      expect(viewModel.profiles, isEmpty);

      expect(viewModel.activeProfile, isNull);
    });

    test('un fallo al borrar un seguimiento detiene la limpieza', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-1',
          createdAt: DateTime.utc(2026, 10, 1),
          trackingNumber: 1,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-2',
          createdAt: DateTime.utc(2026, 10, 2),
          trackingNumber: 2,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-3',
          createdAt: DateTime.utc(2026, 10, 3),
          trackingNumber: 3,
        ),
      ];

      repository.failingId = 'seguimiento-2';

      final result = await viewModel.deleteAllProfilesForAccount();

      expect(result, isFalse);

      expect(repository.deletedIds, ['seguimiento-1']);

      expect(
        viewModel.errorMessage,
        'No fue posible eliminar '
        'el seguimiento de prueba.',
      );
    });

    test('limpia el estado local cuando termina la autenticación', () async {
      repository.profilesToRecover = [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-1',
          createdAt: DateTime.utc(2026, 10, 1),
          trackingNumber: 1,
        ),
      ];

      final initialized = await viewModel.initialize();

      expect(initialized, isTrue);

      expect(viewModel.profiles, isNotEmpty);

      viewModel.clearAuthenticationState();

      expect(viewModel.profiles, isEmpty);

      expect(viewModel.activeProfile, isNull);

      expect(viewModel.isInitialized, isFalse);
    });
  });
}

class _AccountCleanupTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  List<AnonymousTrackingProfile> profilesToRecover = [];

  final List<String> deletedIds = [];

  int recoverCalls = 0;

  String? failingId;

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    recoverCalls++;

    return List.unmodifiable(profilesToRecover);
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<void> deleteProfile(String anonymousId) async {
    if (anonymousId == failingId) {
      throw const TrackingFailure(
        'No fue posible eliminar '
        'el seguimiento de prueba.',
      );
    }

    deletedIds.add(anonymousId);
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado';
  }
}
