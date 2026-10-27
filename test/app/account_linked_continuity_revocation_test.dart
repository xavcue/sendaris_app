import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_linked_continuity_revocation.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

void main() {
  late AccountLinkedContinuityRevocation coordinator;

  late List<String> operations;

  late int nativeCalls;
  late int checkpointCalls;
  late int drainCalls;

  late bool nativeAccepted;
  late bool nativeThrows;
  late bool checkpointThrows;
  late bool drainThrows;

  late FirebaseAccountSlot? nativeSlot;
  late FirebaseAccountSlot? checkpointSlot;
  late String? nativeUserId;
  late String? checkpointUserId;

  Future<void> Function()? onDrain;

  Future<void> revoke({
    FirebaseAccountSlot slot = FirebaseAccountSlot.primary,
    String userId = 'uid-a',
    bool isLinked = true,
  }) {
    return coordinator.revoke(slot: slot, userId: userId, isLinked: isLinked);
  }

  setUp(() {
    operations = <String>[];

    nativeCalls = 0;
    checkpointCalls = 0;
    drainCalls = 0;

    nativeAccepted = true;
    nativeThrows = false;
    checkpointThrows = false;
    drainThrows = false;

    nativeSlot = null;
    checkpointSlot = null;
    nativeUserId = null;
    checkpointUserId = null;

    onDrain = null;

    coordinator = AccountLinkedContinuityRevocation(
      drainLinkedWrites: () async {
        operations.add('drain');
        drainCalls++;

        final callback = onDrain;

        if (callback != null) {
          await callback();
        }

        if (drainThrows) {
          throw StateError('Error al esperar escrituras');
        }
      },
      revokeNative: ({required slot, required expectedUserId}) async {
        operations.add('native');
        nativeCalls++;

        nativeSlot = slot;
        nativeUserId = expectedUserId;

        if (nativeThrows) {
          throw StateError('Error de Android Keystore');
        }

        return nativeAccepted;
      },
      revokeCheckpoint: (slot, userId) async {
        operations.add('checkpoint');
        checkpointCalls++;

        checkpointSlot = slot;
        checkpointUserId = userId;

        if (checkpointThrows) {
          throw StateError('Error del diario persistente');
        }
      },
    );
  });

  group('AUTH-03 B8.10B.10C.3J.1 - Revocacion nativa', () {
    test('A ejecuta ambas revocaciones', () async {
      await revoke();

      expect(drainCalls, 1);
      expect(nativeCalls, 1);
      expect(checkpointCalls, 1);

      expect(coordinator.isBusy, isFalse);
    });

    test('respeta el orden de seguridad', () async {
      await revoke();

      expect(operations, <String>['drain', 'native', 'checkpoint']);
    });

    test('mantiene el UID y contexto de A', () async {
      await revoke();

      expect(nativeSlot, FirebaseAccountSlot.primary);
      expect(checkpointSlot, FirebaseAccountSlot.primary);

      expect(nativeUserId, 'uid-a');
      expect(checkpointUserId, 'uid-a');
    });

    test('admite una vinculacion en secondary', () async {
      await revoke(slot: FirebaseAccountSlot.secondary, userId: 'uid-a');

      expect(nativeSlot, FirebaseAccountSlot.secondary);
      expect(checkpointSlot, FirebaseAccountSlot.secondary);

      expect(nativeUserId, 'uid-a');
      expect(checkpointUserId, 'uid-a');
    });

    test('B elimina solo su checkpoint', () async {
      await revoke(
        slot: FirebaseAccountSlot.secondary,
        userId: 'uid-b',
        isLinked: false,
      );

      expect(operations, <String>['checkpoint']);

      expect(drainCalls, 0);
      expect(nativeCalls, 0);
      expect(checkpointCalls, 1);

      expect(checkpointSlot, FirebaseAccountSlot.secondary);
      expect(checkpointUserId, 'uid-b');
    });

    test('B convencional en primary tampoco toca Keystore', () async {
      await revoke(
        slot: FirebaseAccountSlot.primary,
        userId: 'uid-b',
        isLinked: false,
      );

      expect(drainCalls, 0);
      expect(nativeCalls, 0);
      expect(checkpointCalls, 1);
    });

    test('si Android rechaza, revoca igualmente el checkpoint', () async {
      nativeAccepted = false;

      await expectLater(revoke(), throwsA(isA<StateError>()));

      expect(nativeCalls, 1);
      expect(checkpointCalls, 1);
      expect(coordinator.isBusy, isFalse);
    });

    test('si Android lanza excepcion, sigue con el checkpoint', () async {
      nativeThrows = true;

      await expectLater(revoke(), throwsA(isA<StateError>()));

      expect(operations, <String>['drain', 'native', 'checkpoint']);
      expect(checkpointCalls, 1);
    });

    test('si falla el checkpoint, la revocacion nativa '
        'ya fue solicitada', () async {
      checkpointThrows = true;

      await expectLater(revoke(), throwsA(isA<StateError>()));

      expect(nativeCalls, 1);
      expect(checkpointCalls, 1);
      expect(coordinator.isBusy, isFalse);
    });

    test('si ambas revocaciones fallan no informa exito', () async {
      nativeAccepted = false;
      checkpointThrows = true;

      await expectLater(revoke(), throwsA(isA<StateError>()));

      expect(nativeCalls, 1);
      expect(checkpointCalls, 1);
    });

    test('si la espera de escrituras falla, intenta '
        'ambas revocaciones', () async {
      drainThrows = true;

      await expectLater(revoke(), throwsA(isA<StateError>()));

      expect(drainCalls, 1);
      expect(nativeCalls, 1);
      expect(checkpointCalls, 1);
    });

    test('rechaza UID vacio sin tocar almacenamiento', () async {
      await expectLater(revoke(userId: ''), throwsA(isA<ArgumentError>()));

      expect(operations, isEmpty);
    });

    test('rechaza UID con espacios exteriores', () async {
      await expectLater(
        revoke(userId: ' uid-a '),
        throwsA(isA<ArgumentError>()),
      );

      expect(operations, isEmpty);
    });

    test('rechaza caracteres de control en UID', () async {
      await expectLater(
        revoke(userId: 'uid-a\n'),
        throwsA(isA<ArgumentError>()),
      );

      expect(operations, isEmpty);
    });

    test('rechaza UID excesivamente largo', () async {
      await expectLater(
        revoke(userId: 'a' * 257),
        throwsA(isA<ArgumentError>()),
      );

      expect(operations, isEmpty);
    });

    test('impide dos revocaciones simultaneas', () async {
      final pending = Completer<void>();

      onDrain = () => pending.future;

      final first = revoke();

      // La primera operacion debe estar esperando
      // el drenaje de escrituras.
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isBusy, isTrue);

      await expectLater(
        revoke(
          slot: FirebaseAccountSlot.secondary,
          userId: 'uid-b',
          isLinked: false,
        ),
        throwsA(isA<StateError>()),
      );

      expect(nativeCalls, 0);
      expect(checkpointCalls, 0);

      pending.complete();

      await first;

      expect(coordinator.isBusy, isFalse);
      expect(nativeCalls, 1);
      expect(checkpointCalls, 1);
    });

    test('libera el bloqueo despues de un error', () async {
      nativeAccepted = false;

      await expectLater(revoke(), throwsA(isA<StateError>()));

      expect(coordinator.isBusy, isFalse);

      nativeAccepted = true;

      await revoke();

      expect(nativeCalls, 2);
      expect(checkpointCalls, 2);
    });

    test('permite cierres independientes y secuenciales', () async {
      await revoke(slot: FirebaseAccountSlot.primary, userId: 'uid-a');

      await revoke(
        slot: FirebaseAccountSlot.secondary,
        userId: 'uid-b',
        isLinked: false,
      );

      expect(drainCalls, 1);
      expect(nativeCalls, 1);
      expect(checkpointCalls, 2);

      expect(operations, <String>[
        'drain',
        'native',
        'checkpoint',
        'checkpoint',
      ]);
    });
  });
}
