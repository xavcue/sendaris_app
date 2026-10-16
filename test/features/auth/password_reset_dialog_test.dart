import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/repositories/password_reset_repository.dart';
import 'package:sendaris/features/auth/presentation/views/password_reset_dialog.dart';

void main() {
  testWidgets('permite abrir y cancelar la recuperación', (tester) async {
    final repository = _FakePasswordResetRepository();

    await _pumpDialog(tester, repository);

    expect(find.byKey(const Key('password-reset-dialog')), findsOneWidget);

    expect(find.text('Recuperar contraseña'), findsOneWidget);

    expect(find.textContaining('restablecer tu contraseña'), findsOneWidget);

    expect(find.textContaining('habilitado el acceso'), findsNothing);

    await tester.tap(find.byKey(const Key('password-reset-close-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-reset-dialog')), findsNothing);

    expect(repository.requestedEmails, isEmpty);
  });

  testWidgets('valida el correo antes de enviar', (tester) async {
    final repository = _FakePasswordResetRepository();

    await _pumpDialog(tester, repository);

    await tester.tap(find.byKey(const Key('password-reset-submit-button')));

    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);

    expect(repository.requestedEmails, isEmpty);

    await tester.enterText(
      find.byKey(const Key('password-reset-email-field')),
      'correo-invalido',
    );

    await tester.tap(find.byKey(const Key('password-reset-submit-button')));

    await tester.pump();

    expect(find.text('Ingresa un correo electrónico válido.'), findsOneWidget);

    expect(repository.requestedEmails, isEmpty);
  });

  testWidgets('muestra una confirmación neutral', (tester) async {
    final repository = _FakePasswordResetRepository();

    await _pumpDialog(tester, repository);

    await tester.enterText(
      find.byKey(const Key('password-reset-email-field')),
      'usuario@example.com',
    );

    await tester.tap(find.byKey(const Key('password-reset-submit-button')));

    await tester.pumpAndSettle();

    expect(repository.requestedEmails, ['usuario@example.com']);

    expect(find.byKey(const Key('password-reset-success')), findsOneWidget);

    expect(
      find.textContaining('Si es posible recuperar la contraseña'),
      findsOneWidget,
    );

    expect(find.textContaining('correo no deseado'), findsNothing);

    expect(find.byKey(const Key('password-reset-submit-button')), findsNothing);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester,
  PasswordResetRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) {
                    return PasswordResetDialog(repository: repository);
                  },
                );
              },
              child: const Text('Abrir recuperación'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Abrir recuperación'));
  await tester.pumpAndSettle();
}

class _FakePasswordResetRepository implements PasswordResetRepository {
  final List<String> requestedEmails = [];

  @override
  Future<void> requestPasswordReset({required String email}) async {
    requestedEmails.add(email);
  }
}
