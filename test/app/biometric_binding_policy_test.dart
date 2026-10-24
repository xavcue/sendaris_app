import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';

void main() {
  group('AUTH-03 - Política de vinculación biométrica', () {
    test('sin sesión Firebase exige inicio de sesión normal', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: null,
        binding: const BiometricBindingDisabled(),
      );

      expect(result, BiometricAccessAction.requireSignIn);
    });

    test('una vinculación no reconstruye una sesión inexistente', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: null,
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      expect(result, BiometricAccessAction.requireSignIn);
    });

    test('sin biometría conserva la política temporal anterior', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: const BiometricBindingDisabled(),
      );

      expect(result, BiometricAccessAction.continueLegacySession);
    });

    test('la cuenta vinculada necesita un desafío biométrico', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      expect(result, BiometricAccessAction.requestBiometricVerification);
    });

    test('la cuenta B no puede utilizar la vinculación de A', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-b',
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      expect(result, BiometricAccessAction.denyAccess);
    });

    test('un cambio A-B-A conserva el aislamiento por UID', () {
      const binding = BiometricBindingEnabled(userId: 'uid-a');

      final first = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: binding,
      );

      final second = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-b',
        binding: binding,
      );

      final third = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: binding,
      );

      expect(first, BiometricAccessAction.requestBiometricVerification);

      expect(second, BiometricAccessAction.denyAccess);

      expect(third, BiometricAccessAction.requestBiometricVerification);

      // El resultado del tercer paso exige otro desafío
      // biométrico; nunca reutiliza un desbloqueo anterior.
    });

    test('una configuración ilegible bloquea el acceso', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: const BiometricBindingUnavailable(),
      );

      expect(result, BiometricAccessAction.denyAccess);
    });

    test('una configuración ilegible no equivale a desactivada', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: null,
        binding: const BiometricBindingUnavailable(),
      );

      expect(result, BiometricAccessAction.denyAccess);
    });

    test('una vinculación con UID vacío se rechaza', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: const BiometricBindingEnabled(userId: ''),
      );

      expect(result, BiometricAccessAction.denyAccess);
    });

    test('un UID Firebase vacío no concede acceso', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: '',
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      expect(result, BiometricAccessAction.requireSignIn);
    });

    test('los UID se comparan exactamente, sin normalización', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: const BiometricBindingEnabled(userId: 'UID-A'),
      );

      expect(result, BiometricAccessAction.denyAccess);
    });

    test('un UID alterado con espacios no es aceptado', () {
      final result = BiometricBindingPolicy.decide(
        firebaseUserId: 'uid-a',
        binding: const BiometricBindingEnabled(userId: 'uid-a '),
      );

      expect(result, BiometricAccessAction.denyAccess);
    });
  });
}
