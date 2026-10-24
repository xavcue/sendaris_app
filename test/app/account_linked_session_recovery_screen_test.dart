import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_linked_session_recovery_coordinator.dart';
import 'package:sendaris/app/session/account_linked_session_recovery_screen.dart';

/// Localiza un elemento dentro del ListView.
///
/// A diferencia de ensureVisible, scrollUntilVisible
/// puede desplazar una lista que todavia no ha
/// construido el widget solicitado.
///
/// [backwards] permite regresar a los campos de
/// credenciales despues de mostrar un mensaje.
Future<void> _scrollTo(
  WidgetTester tester,
  String key, {
  bool backwards = false,
}) async {
  final finder = find.byKey(Key(key));

  await tester.scrollUntilVisible(
    finder,
    backwards ? -180.0 : 180.0,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );

  expect(finder, findsOneWidget);
}

/// Introduce las credenciales incluso cuando los
/// campos se encuentran fuera de la zona visible.
Future<void> _enterCredentials(
  WidgetTester tester, {
  String email = 'cuenta@example.com',
  String password = 'ClaveSegura123!',
}) async {
  await _scrollTo(tester, 'linked-recovery-email', backwards: true);

  await tester.enterText(find.byKey(const Key('linked-recovery-email')), email);

  await _scrollTo(tester, 'linked-recovery-password');

  await tester.enterText(
    find.byKey(const Key('linked-recovery-password')),
    password,
  );
}

/// Desplaza el formulario antes de pulsar el boton
/// de autenticacion mediante contrasena.
Future<void> _tapPasswordRecovery(WidgetTester tester) async {
  await _scrollTo(tester, 'linked-recovery-password-submit');

  await tester.tap(find.byKey(const Key('linked-recovery-password-submit')));

  await tester.pump();
}

/// Desplaza el formulario antes de pulsar Google.
Future<void> _tapGoogleRecovery(WidgetTester tester) async {
  await _scrollTo(tester, 'linked-recovery-google-submit');

  await tester.tap(find.byKey(const Key('linked-recovery-google-submit')));

  await tester.pump();
}

void main() {
  group('AUTH-03 B7 - Pantalla de recuperacion vinculada', () {
    testWidgets('no ejecuta autenticacion con credenciales vacias', (
      tester,
    ) async {
      var calls = 0;
      var recoveredCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountLinkedSessionRecoveryScreen(
            onPasswordRecovery: (email, password) async {
              calls++;
              return AccountLinkedRecoveryResult.recovered;
            },
            onSessionRecovered: () {
              recoveredCalls++;
            },
          ),
        ),
      );

      await _tapPasswordRecovery(tester);

      expect(calls, 0);
      expect(recoveredCalls, 0);

      // El mensaje puede aparecer debajo del boton
      // y no estar construido inmediatamente.
      await _scrollTo(tester, 'linked-recovery-message');

      expect(find.byKey(const Key('linked-recovery-message')), findsOneWidget);

      expect(
        find.textContaining('Ingresa tu correo y contraseña.'),
        findsOneWidget,
      );
    });

    testWidgets('espera la autenticacion y confirma recuperacion '
        'sin conceder acceso privado', (tester) async {
      final pending = Completer<AccountLinkedRecoveryResult>();

      var calls = 0;
      var recoveredCalls = 0;

      String? receivedEmail;
      String? receivedPassword;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountLinkedSessionRecoveryScreen(
            onPasswordRecovery: (email, password) {
              calls++;
              receivedEmail = email;
              receivedPassword = password;

              return pending.future;
            },
            onSessionRecovered: () {
              recoveredCalls++;
            },
          ),
        ),
      );

      await _enterCredentials(tester);

      // Guardar la referencia al controlador antes
      // de desplazarse hacia el boton.
      //
      // Si Flutter desmonta temporalmente el campo
      // por estar fuera de pantalla, podemos seguir
      // comprobando que su contenido fue limpiado.
      final passwordController = tester
          .widget<TextField>(find.byKey(const Key('linked-recovery-password')))
          .controller!;

      await _tapPasswordRecovery(tester);

      expect(calls, 1);

      expect(receivedEmail, 'cuenta@example.com');

      expect(receivedPassword, 'ClaveSegura123!');

      expect(passwordController.text, isEmpty);

      // La operacion sigue pendiente.
      // Por lo tanto, no se confirma recuperacion.
      expect(recoveredCalls, 0);

      await _scrollTo(tester, 'linked-recovery-progress');

      expect(find.byKey(const Key('linked-recovery-progress')), findsOneWidget);

      // El boton debe permanecer deshabilitado
      // durante la autenticacion pendiente.
      await _scrollTo(
        tester,
        'linked-recovery-password-submit',
        backwards: true,
      );

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('linked-recovery-password-submit')),
            )
            .onPressed,
        isNull,
      );

      pending.complete(AccountLinkedRecoveryResult.recovered);

      await tester.pumpAndSettle();

      // Solo se notifica la recuperacion de Firebase.
      // La pantalla no selecciona una cuenta privada.
      expect(recoveredCalls, 1);

      expect(find.byKey(const Key('linked-recovery-progress')), findsNothing);

      expect(find.byKey(const Key('linked-recovery-screen')), findsOneWidget);

      await _scrollTo(tester, 'linked-recovery-password-submit');

      // Una vez recuperada la sesion, la pantalla
      // no debe permitir reenviar la autenticacion.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('linked-recovery-password-submit')),
            )
            .onPressed,
        isNull,
      );

      expect(calls, 1);
    });

    testWidgets('una cuenta incorrecta presenta error '
        'y permite intentar nuevamente', (tester) async {
      var attempts = 0;
      var recoveredCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountLinkedSessionRecoveryScreen(
            onPasswordRecovery: (email, password) async {
              attempts++;

              if (attempts == 1) {
                return AccountLinkedRecoveryResult.accountMismatch;
              }

              return AccountLinkedRecoveryResult.recovered;
            },
            onSessionRecovered: () {
              recoveredCalls++;
            },
          ),
        ),
      );

      await _enterCredentials(tester);

      await _tapPasswordRecovery(tester);

      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(recoveredCalls, 0);

      // El mensaje de error esta despues de
      // los controles de autenticacion.
      await _scrollTo(tester, 'linked-recovery-message');

      expect(find.textContaining('no coincide con'), findsOneWidget);

      // Regresar hacia arriba para introducir
      // las credenciales del segundo intento.
      await _enterCredentials(tester, password: 'OtraClaveSegura123!');

      await _tapPasswordRecovery(tester);

      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(recoveredCalls, 1);

      expect(find.byKey(const Key('linked-recovery-screen')), findsOneWidget);
    });

    testWidgets('Google cancelado no concede acceso '
        'y permite repetir el intento', (tester) async {
      var googleCalls = 0;
      var recoveredCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AccountLinkedSessionRecoveryScreen(
            onPasswordRecovery: (email, password) async {
              return AccountLinkedRecoveryResult.unavailable;
            },
            onGoogleRecovery: () async {
              googleCalls++;

              if (googleCalls == 1) {
                return AccountLinkedRecoveryResult.cancelled;
              }

              return AccountLinkedRecoveryResult.recovered;
            },
            onSessionRecovered: () {
              recoveredCalls++;
            },
          ),
        ),
      );

      await _tapGoogleRecovery(tester);

      await tester.pumpAndSettle();

      expect(googleCalls, 1);
      expect(recoveredCalls, 0);

      await _scrollTo(tester, 'linked-recovery-message');

      expect(find.textContaining('cancelada'), findsOneWidget);

      // El boton vuelve a estar disponible
      // despues de cancelar la autenticacion.
      await _tapGoogleRecovery(tester);

      await tester.pumpAndSettle();

      expect(googleCalls, 2);
      expect(recoveredCalls, 1);

      expect(find.byKey(const Key('linked-recovery-screen')), findsOneWidget);
    });

    testWidgets('no muestra Google si el contexto no '
        'proporciona autenticacion Google', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountLinkedSessionRecoveryScreen(
            onPasswordRecovery: (email, password) async {
              return AccountLinkedRecoveryResult.cancelled;
            },
            onSessionRecovered: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('linked-recovery-screen')), findsOneWidget);

      // La opcion Google no debe construirse
      // si el callback no fue proporcionado.
      expect(
        find.byKey(const Key('linked-recovery-google-submit')),
        findsNothing,
      );

      // El boton de contrasena debe existir,
      // aunque ListView lo construya al desplazarse.
      await _scrollTo(tester, 'linked-recovery-password-submit');

      expect(
        find.byKey(const Key('linked-recovery-password-submit')),
        findsOneWidget,
      );
    });
  });
}
