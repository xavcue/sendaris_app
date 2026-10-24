import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_linked_continuity_emission.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

void main() {
  final startedAt = DateTime.utc(2026, 10, 22, 12);

  late AccountLinkedContinuityEmission emission;
  late SessionTimeoutRecord record;

  late int confirmations;
  late int activations;
  late int revocations;

  late bool confirmationAllowed;
  late bool activationAllowed;
  late bool revocationAllowed;

  late bool throwOnConfirm;
  late bool throwOnActivate;
  late bool throwOnRevoke;

  late FirebaseAccountSlot? receivedSlot;
  late String? receivedUid;
  late DateTime? receivedStartedAt;

  Future<void> Function()? duringActivation;

  Future<bool> confirm() async {
    confirmations++;

    if (throwOnConfirm) {
      throw StateError('Almacenamiento no disponible');
    }

    return confirmationAllowed;
  }

  Future<bool> issue({
    FirebaseAccountSlot slot = FirebaseAccountSlot.primary,
    SessionTimeoutRecord? sessionRecord,
  }) {
    return emission.issue(
      slot: slot,
      record: sessionRecord ?? record,
      confirmAuthorized: confirm,
    );
  }

  setUp(() {
    confirmations = 0;
    activations = 0;
    revocations = 0;

    confirmationAllowed = true;
    activationAllowed = true;
    revocationAllowed = true;

    throwOnConfirm = false;
    throwOnActivate = false;
    throwOnRevoke = false;

    receivedSlot = null;
    receivedUid = null;
    receivedStartedAt = null;

    duringActivation = null;

    record = SessionTimeoutRecord(
      userId: 'uid-a',
      startedAt: startedAt,
      lastActivityAt: startedAt,
    );

    emission = AccountLinkedContinuityEmission(
      activate:
          ({
            required slot,
            required expectedUserId,
            required sessionStartedAt,
          }) async {
            activations++;

            receivedSlot = slot;
            receivedUid = expectedUserId;
            receivedStartedAt = sessionStartedAt;

            final callback = duringActivation;

            if (callback != null) {
              await callback();
            }

            if (throwOnActivate) {
              throw StateError('Keystore no disponible');
            }

            return activationAllowed;
          },
      revoke: ({required slot, required expectedUserId}) async {
        revocations++;

        if (throwOnRevoke) {
          throw StateError('Revocacion no disponible');
        }

        return revocationAllowed;
      },
    );
  });

  group('AUTH-03 B8.10B.10C.3E - Emision de A', () {
    test('requiere confirmacion antes de emitir', () async {
      confirmationAllowed = false;

      expect(await issue(), isFalse);
      expect(confirmations, 1);
      expect(activations, 0);
      expect(revocations, 0);
    });

    test('emite solo despues de confirmar el registro', () async {
      expect(await issue(), isTrue);

      expect(confirmations, 2);
      expect(activations, 1);
      expect(revocations, 0);
    });

    test('conserva UID contexto y fecha original', () async {
      expect(await issue(), isTrue);

      expect(receivedSlot, FirebaseAccountSlot.primary);
      expect(receivedUid, 'uid-a');
      expect(receivedStartedAt, startedAt);
    });

    test('admite una vinculacion ubicada en secondary', () async {
      expect(await issue(slot: FirebaseAccountSlot.secondary), isTrue);

      expect(receivedSlot, FirebaseAccountSlot.secondary);
      expect(receivedUid, 'uid-a');
    });

    test('rechazo nativo no concede continuidad', () async {
      activationAllowed = false;

      expect(await issue(), isFalse);

      expect(activations, 1);
      expect(confirmations, 1);
      expect(revocations, 0);
    });

    test('error nativo no concede continuidad', () async {
      throwOnActivate = true;

      expect(await issue(), isFalse);
      expect(emission.isBusy, isFalse);
    });

    test('error del almacenamiento impide emitir', () async {
      throwOnConfirm = true;

      expect(await issue(), isFalse);
      expect(activations, 0);
      expect(emission.isBusy, isFalse);
    });

    test('cierre concurrente revoca una emision', () async {
      duringActivation = () async {
        confirmationAllowed = false;
      };

      expect(await issue(), isFalse);

      expect(confirmations, 2);
      expect(activations, 1);
      expect(revocations, 1);
    });

    test('cambio de autorizacion tras emitir revoca', () async {
      duringActivation = () async {
        confirmationAllowed = false;
      };

      expect(await issue(), isFalse);
      expect(revocations, 1);
    });

    test('error de revocacion nunca informa exito', () async {
      duringActivation = () async {
        confirmationAllowed = false;
      };

      throwOnRevoke = true;

      expect(await issue(), isFalse);
      expect(revocations, 1);
      expect(emission.isBusy, isFalse);
    });

    test('revocacion rechazada nunca informa exito', () async {
      duringActivation = () async {
        confirmationAllowed = false;
      };

      revocationAllowed = false;

      expect(await issue(), isFalse);
      expect(revocations, 1);
    });

    test('UID vacio no realiza operaciones nativas', () async {
      final invalid = SessionTimeoutRecord(
        userId: '',
        startedAt: startedAt,
        lastActivityAt: startedAt,
      );

      expect(await issue(sessionRecord: invalid), isFalse);

      expect(confirmations, 0);
      expect(activations, 0);
    });

    test('UID con espacios no realiza operaciones', () async {
      final invalid = SessionTimeoutRecord(
        userId: ' uid-a ',
        startedAt: startedAt,
        lastActivityAt: startedAt,
      );

      expect(await issue(sessionRecord: invalid), isFalse);

      expect(activations, 0);
    });

    test('fecha de inicio invalida impide la emision', () async {
      final invalidDate = DateTime.utc(1969, 12, 31);

      final invalid = SessionTimeoutRecord(
        userId: 'uid-a',
        startedAt: invalidDate,
        lastActivityAt: invalidDate,
      );

      expect(await issue(sessionRecord: invalid), isFalse);

      expect(activations, 0);
    });

    test('no permite dos emisiones simultaneas', () async {
      final pending = Completer<void>();

      duringActivation = () async {
        await pending.future;
      };

      final first = issue();

      await Future<void>.delayed(Duration.zero);

      expect(emission.isBusy, isTrue);

      final second = await issue();

      expect(second, isFalse);
      expect(activations, 1);

      pending.complete();

      expect(await first, isTrue);
      expect(emission.isBusy, isFalse);
    });

    test('puede procesar una nueva operacion '
        'despues de finalizar la anterior', () async {
      expect(await issue(), isTrue);
      expect(emission.isBusy, isFalse);

      expect(await issue(), isTrue);
      expect(emission.isBusy, isFalse);

      expect(activations, 2);

      // Kotlin conserva su propio control de
      // autorizacion de un solo uso.
      // Este test verifica solamente que la
      // capa Dart no queda bloqueada.
    });
  });
}
