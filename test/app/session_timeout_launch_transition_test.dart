import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

final class _Identity implements AccountIdentitySource {
  _Identity(this.currentUserId);

  @override
  final String? currentUserId;

  final _changes = StreamController<String?>.broadcast(sync: true);

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

final class _Auth implements AuthRepository, AuthIdentityRepository {
  _Auth(this.currentUserId);

  @override
  final String? currentUserId;

  final _authChanges = StreamController<bool>.broadcast(sync: true);
  final _identityChanges = StreamController<String?>.broadcast(sync: true);

  @override
  bool get isAuthenticated => currentUserId != null;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  @override
  Future<void> signIn({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _ControlledStore implements SessionTimeoutStore {
  final gate = Completer<void>();

  bool failWrites = true;

  SessionTimeoutRecord? current;

  @override
  Future<SessionTimeoutRecord?> read() async => current;

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    await gate.future;

    if (failWrites) {
      throw StateError('Fallo simulado de persistencia');
    }

    current = record;
  }

  @override
  Future<void> clear() async {
    current = null;
  }
}

final class _PrivateMarker extends StatefulWidget {
  const _PrivateMarker({required this.onMounted});

  final VoidCallback onMounted;

  @override
  State<_PrivateMarker> createState() => _PrivateMarkerState();
}

final class _PrivateMarkerState extends State<_PrivateMarker> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: Text('Contenido privado')));
  }
}

void main() {
  testWidgets(
    'durante la comprobacion B solo muestra la marca, nunca datos privados',
    (tester) async {
      final primary = _Identity(null);
      final secondary = _Identity('uid-b');
      final auth = _Auth('uid-b');
      final store = _ControlledStore();

      final selection = AccountSessionSelectionController(
        primary: primary,
        secondary: secondary,
      );

      final selected = await selection.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: () async => true,
      );

      expect(selected, isTrue);

      final now = DateTime.utc(2026, 10, 23, 17);
      var privateMounts = 0;

      await tester.pumpWidget(
        SessionTimeoutGuard(
          authRepository: auth,
          store: store,
          accessSelection: selection,
          conventionalSlot: FirebaseAccountSlot.secondary,
          initialRecord: SessionTimeoutRecord(
            userId: 'uid-b',
            startedAt: now,
            lastActivityAt: now,
          ),
          clock: () => now,
          child: _PrivateMarker(onMounted: () => privateMounts++),
        ),
      );

      expect(privateMounts, 0);
      expect(find.text('Contenido privado'), findsNothing);
      expect(find.text('Protegiendo tu sesión'), findsNothing);
      expect(
        find.text('Comprobando la vigencia de tu acceso...'),
        findsNothing,
      );

      expect(
        find.byKey(const Key('session-timeout-protection')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('sendaris-launch-circular-logo')),
        findsOneWidget,
      );

      // Un fallo real mantiene B cerrada y ofrece reintentar.
      store.gate.complete();
      await tester.pumpAndSettle();

      expect(privateMounts, 0);
      expect(find.byKey(const Key('session-timeout-retry')), findsOneWidget);
      expect(find.text('Protegiendo tu sesión'), findsNothing);

      store.failWrites = false;

      await tester.tap(find.byKey(const Key('session-timeout-retry')));

      await tester.pumpAndSettle();

      expect(privateMounts, 1);
      expect(find.text('Contenido privado'), findsOneWidget);

      expect(find.byKey(const Key('session-timeout-protection')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());

      selection.dispose();
      await primary.dispose();
      await secondary.dispose();
      await auth.dispose();
    },
  );
}
