import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('TrackingViewModel - contexto de autenticación', () {
    late _ControlledTrackingRepository repository;
    late TrackingViewModel viewModel;

    setUp(() {
      repository = _ControlledTrackingRepository();

      viewModel = TrackingViewModel(
        repository,
        AnonymousTrackingProfileFactory(_FixedAnonymousIdGenerator()),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('no permite operaciones sin una cuenta autenticada', () async {
      viewModel.synchronizeAuthenticationContext(null);

      expect(await viewModel.initialize(), isFalse);
      expect(await viewModel.recoverProfiles(), isFalse);
      expect(await viewModel.createAndPersistProfile(), isFalse);
      expect(await viewModel.deleteAllProfilesForAccount(), isFalse);

      expect(repository.recoverCalls, 0);
      expect(repository.persistedIds, isEmpty);
      expect(repository.deletedIds, isEmpty);
      expect(viewModel.profiles, isEmpty);
      expect(viewModel.isInitialized, isFalse);
    });

    test(
      'una recuperación tardía de A no reemplaza los perfiles de B',
      () async {
        final pendingA = Completer<List<AnonymousTrackingProfile>>();

        repository.recoveryResponses.add(pendingA.future);

        viewModel.synchronizeAuthenticationContext('uid-a');

        final operationA = viewModel.recoverProfiles();

        expect(viewModel.isLoading, isTrue);

        viewModel.synchronizeAuthenticationContext('uid-b');

        repository.recoveryResponses.add(
          Future.value([_profile('seguimiento-b')]),
        );

        final resultB = await viewModel.recoverProfiles();

        expect(resultB, isTrue);
        expect(viewModel.activeAnonymousId, 'seguimiento-b');

        pendingA.complete([_profile('seguimiento-a')]);

        final resultA = await operationA;

        expect(resultA, isFalse);
        expect(viewModel.profiles, hasLength(1));
        expect(viewModel.activeAnonymousId, 'seguimiento-b');
        expect(viewModel.isInitialized, isTrue);
        expect(viewModel.isLoading, isFalse);
      },
    );

    test('un error tardío de A no altera el estado de B', () async {
      final pendingA = Completer<List<AnonymousTrackingProfile>>();

      repository.recoveryResponses.add(pendingA.future);

      viewModel.synchronizeAuthenticationContext('uid-a');

      final operationA = viewModel.initialize();

      viewModel.synchronizeAuthenticationContext('uid-b');

      pendingA.completeError(
        const TrackingFailure('Error perteneciente a la cuenta anterior.'),
      );

      final resultA = await operationA;

      expect(resultA, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.successMessage, isNull);
      expect(viewModel.profiles, isEmpty);
      expect(viewModel.isInitialized, isFalse);
      expect(viewModel.isLoading, isFalse);
    });

    test('una creación pendiente de A no aparece en B', () async {
      final writeStarted = Completer<void>();
      final pendingWrite = Completer<void>();

      repository.onPersist = (profile) {
        if (!writeStarted.isCompleted) {
          writeStarted.complete();
        }

        return pendingWrite.future;
      };

      viewModel.synchronizeAuthenticationContext('uid-a');

      final operationA = viewModel.createAndPersistProfile();

      await writeStarted.future;

      expect(repository.persistedIds, hasLength(1));

      viewModel.synchronizeAuthenticationContext('uid-b');

      pendingWrite.complete();

      final resultA = await operationA;

      expect(resultA, isFalse);
      expect(viewModel.profiles, isEmpty);
      expect(viewModel.activeProfile, isNull);
      expect(viewModel.successMessage, isNull);
      expect(viewModel.isInitialized, isFalse);
    });

    test('una numeración pendiente de A no inicializa la cuenta B', () async {
      final writeStarted = Completer<void>();
      final pendingWrite = Completer<void>();

      repository.recoveryResponses.add(
        Future.value([
          _profile('seguimiento-a-sin-numero', trackingNumber: null),
        ]),
      );

      repository.onPersist = (profile) {
        if (!writeStarted.isCompleted) {
          writeStarted.complete();
        }

        return pendingWrite.future;
      };

      viewModel.synchronizeAuthenticationContext('uid-a');

      final operationA = viewModel.initialize();

      await writeStarted.future;

      expect(repository.persistedIds, ['seguimiento-a-sin-numero']);

      viewModel.synchronizeAuthenticationContext('uid-b');

      pendingWrite.complete();

      final resultA = await operationA;

      expect(resultA, isFalse);
      expect(viewModel.profiles, isEmpty);
      expect(viewModel.activeAnonymousId, isNull);
      expect(viewModel.isInitialized, isFalse);
    });

    test(
      'una eliminación pendiente de A no modifica los perfiles de B',
      () async {
        repository.recoveryResponses.add(
          Future.value([_profile('seguimiento-a')]),
        );

        viewModel.synchronizeAuthenticationContext('uid-a');

        expect(await viewModel.recoverProfiles(), isTrue);

        final deleteStarted = Completer<void>();
        final pendingDelete = Completer<void>();

        repository.onDelete = (anonymousId) {
          if (!deleteStarted.isCompleted) {
            deleteStarted.complete();
          }

          return pendingDelete.future;
        };

        final operationA = viewModel.deleteProfiles({'seguimiento-a'});

        await deleteStarted.future;

        viewModel.synchronizeAuthenticationContext('uid-b');

        repository.recoveryResponses.add(
          Future.value([_profile('seguimiento-b')]),
        );

        expect(await viewModel.recoverProfiles(), isTrue);

        pendingDelete.complete();

        final resultA = await operationA;

        expect(resultA, isFalse);
        expect(viewModel.profiles, hasLength(1));
        expect(viewModel.activeAnonymousId, 'seguimiento-b');
        expect(viewModel.isInitialized, isTrue);
      },
    );

    test(
      'la limpieza de A no inicia eliminaciones después del cambio a B',
      () async {
        final pendingRecovery = Completer<List<AnonymousTrackingProfile>>();

        repository.recoveryResponses.add(pendingRecovery.future);

        viewModel.synchronizeAuthenticationContext('uid-a');

        final operationA = viewModel.deleteAllProfilesForAccount();

        viewModel.synchronizeAuthenticationContext('uid-b');

        pendingRecovery.complete([
          _profile('seguimiento-a-1'),
          _profile('seguimiento-a-2'),
        ]);

        final resultA = await operationA;

        expect(resultA, isFalse);
        expect(repository.deletedIds, isEmpty);
        expect(viewModel.profiles, isEmpty);
        expect(viewModel.successMessage, isNull);
      },
    );

    test('un resultado de A anterior no se acepta al regresar a A', () async {
      final oldRecovery = Completer<List<AnonymousTrackingProfile>>();

      repository.recoveryResponses.add(oldRecovery.future);

      viewModel.synchronizeAuthenticationContext('uid-a');

      final oldOperation = viewModel.recoverProfiles();

      viewModel.synchronizeAuthenticationContext('uid-b');

      viewModel.synchronizeAuthenticationContext('uid-a');

      repository.recoveryResponses.add(
        Future.value([_profile('seguimiento-a-actual')]),
      );

      final currentResult = await viewModel.recoverProfiles();

      expect(currentResult, isTrue);
      expect(viewModel.activeAnonymousId, 'seguimiento-a-actual');

      oldRecovery.complete([_profile('seguimiento-a-antiguo')]);

      final oldResult = await oldOperation;

      expect(oldResult, isFalse);
      expect(viewModel.profiles, hasLength(1));
      expect(viewModel.activeAnonymousId, 'seguimiento-a-actual');
    });
  });
}

AnonymousTrackingProfile _profile(
  String anonymousId, {
  int? trackingNumber = 1,
}) {
  return AnonymousTrackingProfile(
    anonymousId: anonymousId,
    createdAt: DateTime.utc(2026, 10, 13),
    trackingNumber: trackingNumber,
  );
}

class _ControlledTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  final Queue<Future<List<AnonymousTrackingProfile>>> recoveryResponses =
      Queue();

  final List<String> persistedIds = [];
  final List<String> deletedIds = [];

  Future<void> Function(AnonymousTrackingProfile)? onPersist;
  Future<void> Function(String)? onDelete;

  int recoverCalls = 0;

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() {
    recoverCalls++;

    if (recoveryResponses.isEmpty) {
      return Future.value(<AnonymousTrackingProfile>[]);
    }

    return recoveryResponses.removeFirst();
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) {
    persistedIds.add(profile.anonymousId);

    final handler = onPersist;

    if (handler != null) {
      return handler(profile);
    }

    return Future<void>.value();
  }

  @override
  Future<void> deleteProfile(String anonymousId) {
    deletedIds.add(anonymousId);

    final handler = onDelete;

    if (handler != null) {
      return handler(anonymousId);
    }

    return Future<void>.value();
  }
}

class _FixedAnonymousIdGenerator implements AnonymousIdGenerator {
  @override
  String generate() {
    return 'seguimiento-generado-de-prueba';
  }
}
