import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/linked_account_session_lifecycle_controller.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this.currentUserId);

  @override
  final String? currentUserId;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

void main() {
  group('AUTH-03 3K.1 - restauracion de vigencia de A', () {
    late DateTime now;
    late _FakeIdentity primary;
    late _FakeIdentity secondary;
    late AccountSessionSelectionController selection;
    late LinkedAccountSessionLifecycleController lifecycle;

    setUp(() {
      now = DateTime.utc(2026, 10, 23, 12);

      primary = _FakeIdentity('uid-a');
      secondary = _FakeIdentity(null);

      selection = AccountSessionSelectionController(
        primary: primary,
        secondary: secondary,
      );

      lifecycle = LinkedAccountSessionLifecycleController(
        selection: selection,
        linkedSlot: FirebaseAccountSlot.primary,
        clock: () => now,
      );
    });

    tearDown(() async {
      lifecycle.dispose();
      selection.dispose();

      await primary.dispose();
      await secondary.dispose();
    });

    Future<void> authorize() async {
      expect(
        await selection.select(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          verifyAccess: () async => true,
        ),
        isTrue,
      );
    }

    SessionTimeoutRecord previous({
      Duration age = const Duration(hours: 1),
      Duration idle = const Duration(minutes: 12),
      Duration? background,
    }) {
      return SessionTimeoutRecord(
        userId: 'uid-a',
        startedAt: now.subtract(age),
        lastActivityAt: now.subtract(idle),
        backgroundAt: background == null ? null : now.subtract(background),
      );
    }

    test('sin autorizacion previa no concede acceso', () {
      final success = lifecycle.restoreAuthorized(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        record: previous(),
      );

      expect(success, isFalse);
      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
    });

    test('reemplaza el inicio provisional por el original', () async {
      await authorize();

      final old = previous();

      expect(lifecycle.record!.startedAt, now);

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          record: old,
        ),
        isTrue,
      );

      expect(lifecycle.record!.startedAt, old.startedAt);
      expect(lifecycle.record!.lastActivityAt, now);
      expect(lifecycle.record!.backgroundAt, isNull);
      expect(lifecycle.hasValidLinkedAccess, isTrue);
    });

    test(
      'restaura el regreso desde segundo plano sin renovar inicio',
      () async {
        await authorize();

        final old = previous(background: const Duration(minutes: 10));

        expect(
          lifecycle.restoreAuthorized(
            slot: FirebaseAccountSlot.primary,
            expectedUserId: 'uid-a',
            record: old,
          ),
          isTrue,
        );

        expect(lifecycle.record!.startedAt, old.startedAt);
        expect(lifecycle.record!.backgroundAt, isNull);
        expect(lifecycle.record!.lastActivityAt, now);
        expect(lifecycle.isBackgrounded, isFalse);
      },
    );

    test(
      'admite la ventana de retorno solo para un registro vigente',
      () async {
        await authorize();

        final old = previous(
          age: const Duration(hours: 3),
          idle: const Duration(minutes: 90),
        );

        expect(old.isExpired(now, restoring: true), isFalse);

        expect(
          lifecycle.restoreAuthorized(
            slot: FirebaseAccountSlot.primary,
            expectedUserId: 'uid-a',
            record: old,
          ),
          isTrue,
        );

        expect(lifecycle.record!.startedAt, old.startedAt);
        expect(lifecycle.record!.lastActivityAt, now);
      },
    );

    test('rechaza la vigencia absoluta caducada y bloquea A', () async {
      await authorize();

      final expired = previous(
        age: SessionTimeoutPolicy.absolute + const Duration(seconds: 1),
      );

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          record: expired,
        ),
        isFalse,
      );

      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
    });

    test('rechaza un segundo plano caducado y bloquea A', () async {
      await authorize();

      final expired = previous(
        age: const Duration(hours: 4),
        idle: const Duration(hours: 3),
        background:
            SessionTimeoutPolicy.background + const Duration(minutes: 1),
      );

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          record: expired,
        ),
        isFalse,
      );

      expect(selection.value, isFalse);
    });

    test('rechaza UID distinto sin mantener acceso provisional', () async {
      await authorize();

      final wrong = SessionTimeoutRecord(
        userId: 'uid-b',
        startedAt: now.subtract(const Duration(hours: 1)),
        lastActivityAt: now.subtract(const Duration(minutes: 5)),
      );

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          record: wrong,
        ),
        isFalse,
      );

      expect(selection.value, isFalse);
    });

    test('rechaza un slot diferente y bloquea A', () async {
      await authorize();

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.secondary,
          expectedUserId: 'uid-a',
          record: previous(),
        ),
        isFalse,
      );

      expect(selection.value, isFalse);
    });

    test('el limite de 24 horas conserva el inicio anterior', () async {
      await authorize();

      final old = previous(
        age: SessionTimeoutPolicy.absolute - const Duration(minutes: 20),
        idle: const Duration(minutes: 5),
      );

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          record: old,
        ),
        isTrue,
      );

      now = now.add(const Duration(minutes: 21));

      lifecycle.checkCurrentValidity();

      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
    });

    test('el cierre de A borra la vigencia restaurada', () async {
      await authorize();

      expect(
        lifecycle.restoreAuthorized(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          record: previous(),
        ),
        isTrue,
      );

      lifecycle.closeLinkedAccess();

      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
    });
  });
}
