import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/registration_email_view.dart';

void main() {
  testWidgets('Confirmar contraseña restringe pegado y autocompletado', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final authViewModel = AuthViewModel(repository);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      authViewModel.dispose();
      await repository.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(520, 1100));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp(
          home: RegistrationEmailView(onBack: () {}, onLogin: () {}),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final passwordFinder = find.byKey(const Key('registration-password-field'));

    final confirmationFinder = find.byKey(
      const Key('registration-password-confirmation-field'),
    );

    expect(passwordFinder, findsOneWidget);
    expect(confirmationFinder, findsOneWidget);

    final primaryField = tester.widget<TextField>(
      find.descendant(of: passwordFinder, matching: find.byType(TextField)),
    );

    final confirmationField = tester.widget<TextField>(
      find.descendant(of: confirmationFinder, matching: find.byType(TextField)),
    );

    expect(primaryField.autofillHints, contains(AutofillHints.newPassword));

    expect(confirmationField.autofillHints, isNull);

    expect(confirmationField.contextMenuBuilder, isNotNull);

    final confirmationContext = tester.element(confirmationFinder);

    final pasteAction = Actions.maybeFind<PasteTextIntent>(confirmationContext);

    expect(pasteAction, isA<CallbackAction<PasteTextIntent>>());

    final editableState = tester.state<EditableTextState>(
      find.descendant(
        of: confirmationFinder,
        matching: find.byType(EditableText),
      ),
    );

    final toolbar = confirmationField.contextMenuBuilder!(
      confirmationContext,
      editableState,
    );

    if (toolbar is AdaptiveTextSelectionToolbar) {
      expect(
        toolbar.buttonItems?.any(
          (item) => item.type == ContextMenuButtonType.paste,
        ),
        isFalse,
      );
    } else {
      expect(toolbar, isA<SizedBox>());
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Confirmar contraseña permite escribir y conserva validación', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final authViewModel = AuthViewModel(repository);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      authViewModel.dispose();
      await repository.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(520, 1100));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp(
          home: RegistrationEmailView(onBack: () {}, onLogin: () {}),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final email = find.byKey(const Key('registration-email-field'));

    final password = find.byKey(const Key('registration-password-field'));

    final confirmation = find.byKey(
      const Key('registration-password-confirmation-field'),
    );

    final createButton = find.byKey(
      const Key('registration-create-account-button'),
    );

    await tester.enterText(email, 'prueba@sendaris.test');

    await tester.enterText(password, 'Sendaris2026!');

    await tester.ensureVisible(confirmation);

    await tester.enterText(confirmation, 'NoCoincide2026!');

    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.enterText(confirmation, 'Sendaris2026!');

    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);

    expect(repository.registrationCount, 0);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAuthRepository
    implements
        AuthRepository,
        AuthRegistrationRepository,
        AuthEmailVerificationRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  int registrationCount = 0;

  @override
  bool get isAuthenticated => false;

  @override
  String? get currentUserEmail => null;

  @override
  bool get isCurrentUserEmailVerified => false;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    registrationCount++;
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async => false;

  Future<void> dispose() async {
    await _controller.close();
  }
}
