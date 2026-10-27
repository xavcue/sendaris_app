import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_biometric_settings_controller.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this._userId);

  String? _userId;

  final _changes = StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  void changeTo(String? userId) {
    _userId = userId;
    _changes.add(userId);
  }

  Future<void> dispose() => _changes.close();
}

final class _FakeFirebaseVerifier implements AccountFirebaseSessionVerifier {
  _FakeFirebaseVerifier(this.identity);

  final _FakeIdentity identity;

  bool valid = true;
  int validationCalls = 0;

  Future<bool> Function()? onValidate;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final callback = onValidate;

    final validSession = callback == null ? valid : await callback();

    return validSession && identity.currentUserId == expectedUserId;
  }
}

final class _FakeVault implements BiometricVaultGateway {
  BiometricBindingState binding = const BiometricBindingDisabled();

  BiometricVaultOutcome enrollOutcome = BiometricVaultOutcome.verified;

  Future<BiometricVaultOutcome> Function(String)? onEnroll;

  bool mutateOnEnroll = true;
  bool unavailable = false;

  int enrollCalls = 0;
  int readCalls = 0;
  int clearCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() async {
    readCalls++;

    if (unavailable) {
      return const BiometricBindingUnavailable();
    }

    return binding;
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;

    final callback = onEnroll;

    final result = callback == null ? enrollOutcome : await callback(userId);

    if (result == BiometricVaultOutcome.verified && mutateOnEnroll) {
      binding = BiometricBindingEnabled(userId: userId);
    }

    return result;
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async {
    clearCalls++;
    return false;
  }
}

final class _FakeUnlink implements BiometricUnlinkGateway {
  _FakeUnlink(this.vault);

  final _FakeVault vault;

  BiometricVaultOutcome outcome = BiometricVaultOutcome.verified;

  bool mutateOnSuccess = true;
  int calls = 0;

  @override
  Future<BiometricVaultOutcome> deactivate({
    required String expectedUserId,
  }) async {
    calls++;

    final binding = vault.binding;

    if (binding is! BiometricBindingEnabled ||
        binding.userId != expectedUserId) {
      return BiometricVaultOutcome.denied;
    }

    if (outcome == BiometricVaultOutcome.verified && mutateOnSuccess) {
      vault.binding = const BiometricBindingDisabled();
    }

    return outcome;
  }
}

void main() {
  late _FakeIdentity primaryIdentity;
  late _FakeIdentity secondaryIdentity;

  late _FakeFirebaseVerifier primarySession;
  late _FakeFirebaseVerifier secondarySession;

  late AccountSessionSelectionController selection;

  late _FakeVault vault;
  late _FakeUnlink unlink;

  late AccountBiometricSettingsController controller;

  late List<AccountBiometricBindingChange> appliedChanges;

  Future<bool> Function(AccountBiometricBindingChange)? customApply;

  setUp(() {
    primaryIdentity = _FakeIdentity('uid-a');
    secondaryIdentity = _FakeIdentity('uid-b');

    primarySession = _FakeFirebaseVerifier(primaryIdentity);

    secondarySession = _FakeFirebaseVerifier(secondaryIdentity);

    selection = AccountSessionSelectionController(
      primary: primaryIdentity,
      secondary: secondaryIdentity,
    );

    vault = _FakeVault();
    unlink = _FakeUnlink(vault);

    appliedChanges = [];
    customApply = null;

    controller = AccountBiometricSettingsController(
      selection: selection,
      primarySession: primarySession,
      secondarySession: secondarySession,
      gateway: vault,
      unlinkGateway: unlink,
      onBindingChanged: (change) async {
        appliedChanges.add(change);

        final callback = customApply;

        if (callback != null) {
          return await callback(change);
        }

        return true;
      },
    );
  });

  tearDown(() async {
    controller.dispose();
    selection.dispose();

    await primaryIdentity.dispose();
    await secondaryIdentity.dispose();
  });

  Future<bool> authorizeA() {
    return selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );
  }

  Future<bool> authorizeB() {
    return selection.select(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: 'uid-b',
      verifyAccess: () async => true,
    );
  }

  group('AccountBiometricSettingsController', () {
    test('sin autorizacion privada no configura biometria', () async {
      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.notAuthorized,
      );

      expect(vault.enrollCalls, 0);
      expect(unlink.calls, 0);
      expect(appliedChanges, isEmpty);
    });

    test('activa A y conserva el acceso cuando la raiz confirma', () async {
      expect(await authorizeA(), isTrue);

      final result = await controller.activate();

      expect(result, AccountBiometricSettingsResult.activated);

      expect(vault.enrollCalls, 1);
      expect(primarySession.validationCalls, 2);
      expect(appliedChanges, hasLength(1));

      final change = appliedChanges.single;

      expect(change.userId, 'uid-a');
      expect(change.slot, FirebaseAccountSlot.primary);
      expect(change.enabled, isTrue);

      expect((vault.binding as BiometricBindingEnabled).userId, 'uid-a');

      // La cuenta puede permanecer en Ajustes.
      expect(selection.value, isTrue);
      expect(selection.selectedUserId, 'uid-a');

      expect(vault.clearCalls, 0);
    });

    test('desactiva A y conserva la misma sesion autorizada', () async {
      vault.binding = BiometricBindingEnabled(userId: 'uid-a');

      expect(await authorizeA(), isTrue);

      final result = await controller.deactivate();

      expect(result, AccountBiometricSettingsResult.deactivated);

      expect(unlink.calls, 1);
      expect(vault.binding, isA<BiometricBindingDisabled>());

      expect(appliedChanges, hasLength(1));

      final change = appliedChanges.single;

      expect(change.enabled, isFalse);
      expect(change.userId, 'uid-a');
      expect(change.slot, FirebaseAccountSlot.primary);

      expect(selection.value, isTrue);
      expect(selection.selectedUserId, 'uid-a');
      expect(primaryIdentity.currentUserId, 'uid-a');

      expect(vault.clearCalls, 0);
    });

    test('B no puede desactivar la vinculacion de A', () async {
      vault.binding = BiometricBindingEnabled(userId: 'uid-a');

      expect(await authorizeB(), isTrue);

      expect(
        await controller.deactivate(),
        AccountBiometricSettingsResult.otherAccountBound,
      );

      expect(unlink.calls, 0);
      expect(appliedChanges, isEmpty);
      expect(selection.value, isTrue);
    });

    test('B no puede reemplazar la vinculacion de A', () async {
      vault.binding = BiometricBindingEnabled(userId: 'uid-a');

      expect(await authorizeB(), isTrue);

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.otherAccountBound,
      );

      expect(vault.enrollCalls, 0);
      expect(appliedChanges, isEmpty);

      expect((vault.binding as BiometricBindingEnabled).userId, 'uid-a');
    });

    test('una sesion Firebase invalida bloquea el permiso', () async {
      expect(await authorizeA(), isTrue);

      primarySession.valid = false;

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.invalidSession,
      );

      expect(selection.value, isFalse);
      expect(vault.enrollCalls, 0);
      expect(appliedChanges, isEmpty);
    });

    test('cancelar Android sin mutacion conserva Ajustes', () async {
      vault.binding = BiometricBindingEnabled(userId: 'uid-a');

      unlink.outcome = BiometricVaultOutcome.cancelled;

      expect(await authorizeA(), isTrue);

      expect(
        await controller.deactivate(),
        AccountBiometricSettingsResult.cancelled,
      );

      expect(vault.binding, isA<BiometricBindingEnabled>());
      expect(appliedChanges, isEmpty);

      expect(selection.value, isTrue);
      expect(selection.selectedUserId, 'uid-a');
    });

    test('verified sin cambio real es rechazado', () async {
      vault.mutateOnEnroll = false;

      expect(await authorizeA(), isTrue);

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.denied,
      );

      expect(appliedChanges, isEmpty);
      expect(selection.value, isFalse);
    });

    test('detecta A -> C -> A durante el desafio Android', () async {
      expect(await authorizeA(), isTrue);

      final pending = Completer<BiometricVaultOutcome>();

      vault.onEnroll = (_) => pending.future;

      final operation = controller.activate();

      await Future<void>.delayed(Duration.zero);

      primaryIdentity.changeTo('uid-c');
      primaryIdentity.changeTo('uid-a');

      pending.complete(BiometricVaultOutcome.verified);

      expect(await operation, AccountBiometricSettingsResult.identityChanged);

      // Android pudo haber modificado la vinculacion.
      // La raiz recibe la notificacion incluso
      // cuando el acceso ya quedo bloqueado.
      expect(appliedChanges, hasLength(1));
      expect(selection.value, isFalse);
    });

    test('no permite dos operaciones simultaneas', () async {
      expect(await authorizeA(), isTrue);

      final pending = Completer<BiometricVaultOutcome>();

      vault.onEnroll = (_) => pending.future;

      final first = controller.activate();

      expect(controller.isBusy, isTrue);

      expect(
        await controller.deactivate(),
        AccountBiometricSettingsResult.busy,
      );

      pending.complete(BiometricVaultOutcome.verified);

      expect(await first, AccountBiometricSettingsResult.activated);

      expect(controller.isBusy, isFalse);
      expect(vault.enrollCalls, 1);
      expect(unlink.calls, 0);
    });

    test('mutacion pese a cancelacion obliga a actualizar '
        'la raiz y bloquear el acceso', () async {
      expect(await authorizeA(), isTrue);

      vault.onEnroll = (uid) async {
        vault.binding = BiometricBindingEnabled(userId: uid);

        return BiometricVaultOutcome.cancelled;
      };

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.cancelled,
      );

      expect(appliedChanges, hasLength(1));
      expect(selection.value, isFalse);
    });

    test('error de la raiz bloquea la sesion', () async {
      expect(await authorizeA(), isTrue);

      customApply = (_) async {
        throw StateError('Root unavailable');
      };

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.unavailable,
      );

      expect(selection.value, isFalse);
      expect(appliedChanges, hasLength(1));
    });

    test('la raiz puede rechazar expresamente la mutacion', () async {
      expect(await authorizeA(), isTrue);

      customApply = (_) async => false;

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.unavailable,
      );

      expect(selection.value, isFalse);
      expect(appliedChanges, hasLength(1));
    });

    test('detecta cambio de identidad mientras la raiz '
        'confirma la transicion', () async {
      expect(await authorizeA(), isTrue);

      final pending = Completer<bool>();

      customApply = (_) => pending.future;

      final operation = controller.activate();

      await Future<void>.delayed(Duration.zero);

      expect(appliedChanges, hasLength(1));

      primaryIdentity.changeTo('uid-c');
      primaryIdentity.changeTo('uid-a');

      pending.complete(true);

      expect(await operation, AccountBiometricSettingsResult.identityChanged);

      expect(selection.value, isFalse);
    });

    test('si la vinculacion cambia tras confirmar la raiz '
        'se bloquea el acceso', () async {
      expect(await authorizeA(), isTrue);

      customApply = (_) async {
        vault.binding = const BiometricBindingDisabled();

        return true;
      };

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.unavailable,
      );

      expect(selection.value, isFalse);
    });

    test('reconoce vinculacion existente y ausencia de ella', () async {
      expect(await authorizeA(), isTrue);

      expect(
        await controller.deactivate(),
        AccountBiometricSettingsResult.notEnabled,
      );

      vault.binding = BiometricBindingEnabled(userId: 'uid-a');

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.alreadyEnabled,
      );

      expect(vault.enrollCalls, 0);
      expect(unlink.calls, 0);
      expect(appliedChanges, isEmpty);

      expect(selection.value, isTrue);
    });

    test('estado nativo ilegible nunca se considera '
        'desactivado', () async {
      expect(await authorizeA(), isTrue);

      vault.unavailable = true;

      expect(
        await controller.activate(),
        AccountBiometricSettingsResult.unavailable,
      );

      expect(vault.enrollCalls, 0);
      expect(unlink.calls, 0);
      expect(appliedChanges, isEmpty);

      expect(selection.value, isFalse);
    });

    test('verified sin desvinculacion real es rechazado', () async {
      vault.binding = BiometricBindingEnabled(userId: 'uid-a');

      unlink.mutateOnSuccess = false;

      expect(await authorizeA(), isTrue);

      expect(
        await controller.deactivate(),
        AccountBiometricSettingsResult.denied,
      );

      expect(unlink.calls, 1);
      expect(vault.binding, isA<BiometricBindingEnabled>());
      expect(appliedChanges, isEmpty);
      expect(selection.value, isFalse);
    });
  });
}
