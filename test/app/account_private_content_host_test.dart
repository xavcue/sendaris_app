import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_private_content_host.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _FakeIdentitySource implements AccountIdentitySource {
  _FakeIdentitySource(this._userId);

  final StreamController<String?> _controller =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  void changeTo(String? userId) {
    _userId = userId;
    _controller.add(userId);
  }

  Future<void> dispose() => _controller.close();
}

final class _PrivatePanel extends StatefulWidget {
  const _PrivatePanel({
    required this.identity,
    required this.onMounted,
    required this.onUnmounted,
  });

  final String identity;
  final ValueChanged<String> onMounted;
  final ValueChanged<String> onUnmounted;

  @override
  State<_PrivatePanel> createState() => _PrivatePanelState();
}

final class _PrivatePanelState extends State<_PrivatePanel> {
  @override
  void initState() {
    super.initState();
    widget.onMounted(widget.identity);
  }

  @override
  void dispose() {
    widget.onUnmounted(widget.identity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'PRIVADO ${widget.identity}',
        key: const Key('private-account-content'),
      ),
    );
  }
}

void main() {
  late _FakeIdentitySource primary;
  late _FakeIdentitySource secondary;

  late AccountSessionSelectionController selection;

  late List<String> mounts;
  late List<String> unmounts;

  setUp(() {
    primary = _FakeIdentitySource('uid-a');
    secondary = _FakeIdentitySource('uid-b');

    selection = AccountSessionSelectionController(
      primary: primary,
      secondary: secondary,
    );

    mounts = <String>[];
    unmounts = <String>[];
  });

  tearDown(() async {
    selection.dispose();
    await primary.dispose();
    await secondary.dispose();
  });

  Widget buildHost() {
    return MaterialApp(
      home: Scaffold(
        body: AccountPrivateContentHost(
          selection: selection,
          lockedBuilder: (_) {
            return const Center(
              child: Text(
                'LOGIN ORIGINAL',
                key: Key('original-login-placeholder'),
              ),
            );
          },
          privateBuilder: (context, slot, userId) {
            return _PrivatePanel(
              identity: '${slot.name}:$userId',
              onMounted: mounts.add,
              onUnmounted: unmounts.add,
            );
          },
        ),
      ),
    );
  }

  Future<bool> selectPrimary() {
    return selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );
  }

  Future<bool> selectSecondary() {
    return selection.select(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: 'uid-b',
      verifyAccess: () async => true,
    );
  }

  group('AccountPrivateContentHost', () {
    testWidgets('no construye contenido privado sin autorización', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());

      expect(
        find.byKey(const Key('original-login-placeholder')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('private-account-content')), findsNothing);

      expect(mounts, isEmpty);
    });

    testWidgets('monta únicamente el contenido de A', (tester) async {
      await tester.pumpWidget(buildHost());

      expect(await selectPrimary(), isTrue);
      await tester.pump();

      expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

      expect(find.text('PRIVADO secondary:uid-b'), findsNothing);

      expect(mounts, ['primary:uid-a']);
    });

    testWidgets('monta únicamente el contenido de B', (tester) async {
      await tester.pumpWidget(buildHost());

      expect(await selectSecondary(), isTrue);
      await tester.pump();

      expect(find.text('PRIVADO secondary:uid-b'), findsOneWidget);

      expect(find.text('PRIVADO primary:uid-a'), findsNothing);

      expect(mounts, ['secondary:uid-b']);
    });

    testWidgets('desmonta el contenido privado al bloquear', (tester) async {
      await tester.pumpWidget(buildHost());

      expect(await selectPrimary(), isTrue);
      await tester.pump();

      selection.lock();
      await tester.pump();

      expect(find.byKey(const Key('private-account-content')), findsNothing);

      expect(
        find.byKey(const Key('original-login-placeholder')),
        findsOneWidget,
      );

      expect(unmounts, contains('primary:uid-a'));
    });

    testWidgets('oculta A durante una comprobación pendiente para B', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());

      expect(await selectPrimary(), isTrue);
      await tester.pump();

      final pending = Completer<bool>();

      final switching = selection.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: () => pending.future,
      );

      await tester.pump();

      expect(find.byKey(const Key('private-account-content')), findsNothing);

      expect(unmounts, contains('primary:uid-a'));

      pending.complete(true);

      expect(await switching, isTrue);
      await tester.pump();

      expect(find.text('PRIVADO secondary:uid-b'), findsOneWidget);

      expect(find.text('PRIVADO primary:uid-a'), findsNothing);
    });

    testWidgets('una verificación rechazada no conserva A', (tester) async {
      await tester.pumpWidget(buildHost());

      expect(await selectPrimary(), isTrue);
      await tester.pump();

      final granted = await selection.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: () async => false,
      );

      expect(granted, isFalse);

      await tester.pump();

      expect(find.byKey(const Key('private-account-content')), findsNothing);

      expect(
        find.byKey(const Key('original-login-placeholder')),
        findsOneWidget,
      );
    });

    testWidgets('A -> B -> A crea un nuevo State aunque no haya '
        'un fotograma intermedio', (tester) async {
      await tester.pumpWidget(buildHost());

      expect(await selectPrimary(), isTrue);
      await tester.pump();

      expect(mounts, ['primary:uid-a']);

      // Las dos selecciones se completan sin dibujar
      // un fotograma intermedio.
      expect(await selectSecondary(), isTrue);
      expect(await selectPrimary(), isTrue);

      await tester.pump();

      expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

      expect(mounts.where((identity) => identity == 'primary:uid-a').length, 2);

      expect(unmounts, contains('primary:uid-a'));
    });

    testWidgets('una transición de identidad revoca el árbol anterior', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());

      expect(await selectPrimary(), isTrue);
      await tester.pump();

      primary.changeTo('uid-c');
      primary.changeTo('uid-a');

      await tester.pump();

      expect(find.byKey(const Key('private-account-content')), findsNothing);

      expect(
        find.byKey(const Key('original-login-placeholder')),
        findsOneWidget,
      );

      expect(unmounts, contains('primary:uid-a'));
    });

    testWidgets('identidades ambiguas nunca montan datos privados', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());

      secondary.changeTo('uid-a');

      expect(await selectPrimary(), isFalse);

      await tester.pump();

      expect(find.byKey(const Key('private-account-content')), findsNothing);

      expect(mounts, isEmpty);
    });
  });
}
