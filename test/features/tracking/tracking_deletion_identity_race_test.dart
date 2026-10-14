import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('TrackingViewModel - aislamiento de eliminaciones', () {
    late _ControlledTrackingRepository repository;
    late TrackingViewModel viewModel;

    setUp(() {
      repository = _ControlledTrackingRepository();

      viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      viewModel.synchronizeAuthenticationContext('uid-a');
    });

    tearDown(() {
      viewModel.dispose();
    });

    void changeAccount(String? userId) {
      repository.currentUserId = userId;

      viewModel.synchronizeAuthenticationContext(userId);
    }

    test('no inicia mas eliminaciones de A despues del cambio a B', () async {
      repository.deletionGate = Completer<void>();

      final operation = viewModel.deleteAllProfilesForAccount();

      await repository.firstDeletionStarted.future;

      expect(repository.deleteCalls, ['uid-a:seguimiento-a1']);

      changeAccount('uid-b');

      // La nueva cuenta puede inicializarse mientras
      // la operacion antigua continua pendiente.
      final initialized = await viewModel.initialize();

      expect(initialized, isTrue);

      expect(viewModel.profiles.map((profile) => profile.anonymousId), [
        'seguimiento-b1',
      ]);

      repository.deletionGate!.complete();

      final result = await operation;

      expect(
        result,
        isFalse,
        reason:
            'Una eliminacion de A no debe continuar '
            'despues de cambiar a B.',
      );

      expect(repository.deleteCalls, ['uid-a:seguimiento-a1']);

      expect(repository.completedDeletions, ['uid-a:seguimiento-a1']);

      expect(
        viewModel.profiles.map((profile) => profile.anonymousId),
        ['seguimiento-b1'],
        reason:
            'La operacion antigua no debe borrar '
            'el estado local de B.',
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.successMessage, isNull);
    });

    test('A a B a A no reanuda una eliminacion antigua', () async {
      repository.deletionGate = Completer<void>();

      final operation = viewModel.deleteAllProfilesForAccount();

      await repository.firstDeletionStarted.future;

      expect(repository.deleteCalls, ['uid-a:seguimiento-a1']);

      changeAccount('uid-b');
      changeAccount('uid-a');

      repository.deletionGate!.complete();

      final result = await operation;

      expect(
        result,
        isFalse,
        reason:
            'La nueva sesion de A no debe reutilizar '
            'la autorizacion de la sesion anterior.',
      );

      expect(repository.deleteCalls, ['uid-a:seguimiento-a1']);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.successMessage, isNull);
      expect(viewModel.profiles, isEmpty);
    });

    test('un error tardio de eliminacion de A no aparece en B', () async {
      repository.deletionGate = Completer<void>();
      repository.failFirstDeletion = true;

      final operation = viewModel.deleteAllProfilesForAccount();

      await repository.firstDeletionStarted.future;

      changeAccount('uid-b');

      repository.deletionGate!.complete();

      final result = await operation;

      expect(result, isFalse);

      expect(repository.deleteCalls, ['uid-a:seguimiento-a1']);

      expect(
        viewModel.errorMessage,
        isNull,
        reason:
            'Un error perteneciente a A no debe '
            'mostrarse en la cuenta B.',
      );

      expect(viewModel.successMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('una recuperacion antigua no inicia eliminaciones en B', () async {
      repository.recoveryGate = Completer<void>();

      final operation = viewModel.deleteAllProfilesForAccount();

      await repository.firstRecoveryStarted.future;

      expect(repository.deleteCalls, isEmpty);

      changeAccount('uid-b');

      repository.recoveryGate!.complete();

      final result = await operation;

      expect(result, isFalse);

      expect(
        repository.deleteCalls,
        isEmpty,
        reason:
            'No se pueden iniciar eliminaciones '
            'basadas en datos recuperados por A.',
      );

      expect(viewModel.profiles, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('la eliminacion manual de varios perfiles se detiene '
        'cuando cambia el UID', () async {
      final initialized = await viewModel.initialize();

      expect(initialized, isTrue);
      expect(viewModel.profiles.length, 3);

      repository.deletionGate = Completer<void>();

      final operation = viewModel.deleteProfiles({
        'seguimiento-a1',
        'seguimiento-a2',
        'seguimiento-a3',
      });

      await repository.firstDeletionStarted.future;

      expect(repository.deleteCalls, ['uid-a:seguimiento-a1']);

      changeAccount('uid-b');

      repository.deletionGate!.complete();

      final result = await operation;

      expect(result, isFalse);

      expect(
        repository.deleteCalls,
        ['uid-a:seguimiento-a1'],
        reason:
            'Las otras eliminaciones manuales no deben '
            'iniciarse en una nueva sesion.',
      );

      expect(viewModel.profiles, isEmpty);
      expect(viewModel.activeProfile, isNull);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.successMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });
  });
}

class _ControlledTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  String? currentUserId = 'uid-a';

  Completer<void>? recoveryGate;
  Completer<void>? deletionGate;

  final Completer<void> firstRecoveryStarted = Completer<void>();
  final Completer<void> firstDeletionStarted = Completer<void>();

  final List<String> recoveryCalls = [];
  final List<String> deleteCalls = [];
  final List<String> completedDeletions = [];

  bool failFirstDeletion = false;

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    // La cuenta responsable se captura al iniciar
    // la operacion, no cuando termina.
    final requestedUserId = currentUserId;

    recoveryCalls.add(requestedUserId ?? 'sin-sesion');

    if (!firstRecoveryStarted.isCompleted) {
      firstRecoveryStarted.complete();
    }

    final gate = recoveryGate;

    if (gate != null) {
      await gate.future;
    }

    if (requestedUserId == 'uid-a') {
      return [
        _profile('seguimiento-a1', 1),
        _profile('seguimiento-a2', 2),
        _profile('seguimiento-a3', 3),
      ];
    }

    if (requestedUserId == 'uid-b') {
      return [_profile('seguimiento-b1', 1)];
    }

    return [];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<void> deleteProfile(String anonymousId) async {
    // Esta prueba simula una operacion remota que
    // ya quedo asociada a un usuario concreto.
    final requestedUserId = currentUserId;

    deleteCalls.add('$requestedUserId:$anonymousId');

    if (!firstDeletionStarted.isCompleted) {
      firstDeletionStarted.complete();
    }

    final gate = deletionGate;

    if (gate != null) {
      await gate.future;
    }

    if (failFirstDeletion && deleteCalls.length == 1) {
      throw const TrackingFailure(
        'Error simulado durante la eliminacion anterior.',
      );
    }

    completedDeletions.add('$requestedUserId:$anonymousId');
  }

  AnonymousTrackingProfile _profile(String anonymousId, int trackingNumber) {
    return AnonymousTrackingProfile(
      anonymousId: anonymousId,
      createdAt: DateTime.utc(2026, 10, 13),
      trackingNumber: trackingNumber,
    );
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado';
  }
}
