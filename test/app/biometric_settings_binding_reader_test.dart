import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_settings_binding_reader.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('AUTH-03 - Lectura de vinculación desde Ajustes', () {
    _Fixture create({
      String? userId = 'uid-a',
      BiometricBindingState binding = const BiometricBindingDisabled(),
    }) {
      final fixture = _Fixture(userId: userId, binding: binding);

      addTearDown(fixture.dispose);

      return fixture;
    }

    test('sin cuenta Firebase no consulta el almacén nativo', () async {
      final fixture = create(userId: null);

      final result = await fixture.reader.read();

      expect(result, BiometricSettingsBindingStatus.notAuthenticated);

      expect(fixture.vault.readCalls, 0);
    });

    test('la ausencia de vinculación permite mostrar la opción', () async {
      final fixture = create();

      final result = await fixture.reader.read();

      expect(result, BiometricSettingsBindingStatus.disabled);

      expect(fixture.vault.readCalls, 1);
    });

    test('reconoce una vinculación del UID actual', () async {
      final fixture = create(
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      final result = await fixture.reader.read();

      expect(result, BiometricSettingsBindingStatus.enabledForCurrentUser);
    });

    test('distingue una vinculación de otra cuenta', () async {
      final fixture = create(
        binding: const BiometricBindingEnabled(userId: 'uid-b'),
      );

      final result = await fixture.reader.read();

      expect(result, BiometricSettingsBindingStatus.enabledForDifferentUser);
    });

    test(
      'un estado nativo no disponible no se interpreta como desactivado',
      () async {
        final fixture = create(binding: const BiometricBindingUnavailable());

        final result = await fixture.reader.read();

        expect(result, BiometricSettingsBindingStatus.unavailable);
      },
    );

    test('un error del canal nativo no habilita la configuración', () async {
      final fixture = create();

      fixture.vault.failRead = true;

      final result = await fixture.reader.read();

      expect(result, BiometricSettingsBindingStatus.unavailable);

      expect(fixture.vault.enrollCalls, 0);
    });

    test(
      'una salida de sesión durante la lectura invalida el resultado',
      () async {
        final fixture = create();

        final pending = Completer<BiometricBindingState>();

        fixture.vault.pendingRead = pending;

        final resultFuture = fixture.reader.read();

        expect(fixture.vault.readCalls, 1);

        fixture.auth.setUser(null);

        pending.complete(const BiometricBindingDisabled());

        final result = await resultFuture;

        expect(result, BiometricSettingsBindingStatus.identityChanged);
      },
    );

    test(
      'un cambio A-B-A durante la lectura no reutiliza el resultado',
      () async {
        final fixture = create();

        final pending = Completer<BiometricBindingState>();

        fixture.vault.pendingRead = pending;

        final resultFuture = fixture.reader.read();

        expect(fixture.vault.readCalls, 1);

        fixture.auth.setUser('uid-b');
        fixture.auth.setUser('uid-a');

        pending.complete(const BiometricBindingDisabled());

        final result = await resultFuture;

        expect(fixture.auth.currentUserId, 'uid-a');

        expect(result, BiometricSettingsBindingStatus.identityChanged);
      },
    );
  });
}

final class _Fixture {
  _Fixture({required String? userId, required BiometricBindingState binding})
    : auth = _FakeAuth(userId),
      vault = _FakeVault(binding) {
    reader = BiometricSettingsBindingReader(repository: auth, gateway: vault);
  }

  final _FakeAuth auth;
  final _FakeVault vault;

  late final BiometricSettingsBindingReader reader;

  Future<void> dispose() => auth.dispose();
}

final class _FakeAuth implements AuthRepository, AuthIdentityRepository {
  _FakeAuth(this._userId);

  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void setUser(String? userId) {
    _userId = userId;

    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    setUser('uid-a');
  }

  @override
  Future<void> signOut() async {
    setUser(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _FakeVault implements BiometricVaultGateway {
  _FakeVault(this.binding);

  BiometricBindingState binding;

  Completer<BiometricBindingState>? pendingRead;

  bool failRead = false;

  int readCalls = 0;
  int enrollCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() {
    readCalls++;

    if (failRead) {
      return Future<BiometricBindingState>.error(
        StateError('Lectura nativa no disponible'),
      );
    }

    return pendingRead?.future ?? Future<BiometricBindingState>.value(binding);
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;

    return BiometricVaultOutcome.denied;
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async {
    binding = const BiometricBindingDisabled();

    return true;
  }
}
