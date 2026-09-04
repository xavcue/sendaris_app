import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
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

    test('crea y persiste un perfil con identificador anónimo', () async {
      final success = await viewModel.createAndPersistProfile();

      expect(success, true);
      expect(repository.persistedProfiles.length, 1);
      expect(
        repository.persistedProfiles.first.anonymousId,
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(viewModel.profiles.length, 1);
      expect(viewModel.errorMessage, isNull);
    });

    test(
      'recupera perfiles persistidos sin alterar el identificador',
      () async {
        repository.profilesToRecover = [
          AnonymousTrackingProfile(
            anonymousId: '550e8400-e29b-41d4-a716-446655440000',
            createdAt: DateTime.utc(2026, 9, 3),
          ),
        ];

        final success = await viewModel.recoverProfiles();

        expect(success, true);
        expect(viewModel.profiles.length, 1);
        expect(
          viewModel.profiles.first.anonymousId,
          '550e8400-e29b-41d4-a716-446655440000',
        );
        expect(viewModel.errorMessage, isNull);
      },
    );

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

class FakeTrackingRepository implements TrackingRepository {
  final List<AnonymousTrackingProfile> persistedProfiles = [];

  List<AnonymousTrackingProfile> profilesToRecover = [];

  TrackingFailure? recoveryFailure;

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
}

class FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  @override
  String generate() {
    return '550e8400-e29b-41d4-a716-446655440000';
  }
}
