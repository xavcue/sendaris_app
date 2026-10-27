import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_linked_session_recovery_policy.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';

void main() {
  group('AUTH-03 B7.2B - Condiciones para recuperar A', () {
    test(
      'permite recuperacion solamente con A vinculada y ambas sesiones vacias',
      () {
        expect(
          AccountLinkedSessionRecoveryPolicy.canOffer(
            binding: const BiometricBindingEnabled(userId: 'uid-a'),
            primaryUserId: null,
            secondaryUserId: null,
          ),
          isTrue,
        );
      },
    );

    test('rechaza una sesion primaria ajena preexistente', () {
      expect(
        AccountLinkedSessionRecoveryPolicy.canOffer(
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
          primaryUserId: 'uid-b',
          secondaryUserId: null,
        ),
        isFalse,
      );
    });

    test('rechaza una sesion secundaria ajena preexistente', () {
      expect(
        AccountLinkedSessionRecoveryPolicy.canOffer(
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
          primaryUserId: null,
          secondaryUserId: 'uid-c',
        ),
        isFalse,
      );
    });

    test('no habilita recuperacion si ya existe la sesion A', () {
      expect(
        AccountLinkedSessionRecoveryPolicy.canOffer(
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
          primaryUserId: 'uid-a',
          secondaryUserId: null,
        ),
        isFalse,
      );
    });

    test('rechaza una vinculacion ilegible o desactivada', () {
      for (final binding in <BiometricBindingState>[
        const BiometricBindingUnavailable(),
        const BiometricBindingDisabled(),
      ]) {
        expect(
          AccountLinkedSessionRecoveryPolicy.canOffer(
            binding: binding,
            primaryUserId: null,
            secondaryUserId: null,
          ),
          isFalse,
        );
      }
    });

    test('rechaza UID vacio o con espacios en los extremos', () {
      for (final userId in <String>['', ' ', ' uid-a', 'uid-a ']) {
        expect(
          AccountLinkedSessionRecoveryPolicy.canOffer(
            binding: BiometricBindingEnabled(userId: userId),
            primaryUserId: null,
            secondaryUserId: null,
          ),
          isFalse,
        );
      }
    });
  });
}
