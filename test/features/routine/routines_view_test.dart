import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/presentation/views/routines_view.dart';

void main() {
  group('RoutinesView', () {
    testWidgets(
      'muestra la raíz de Rutinas con dos opciones en una sola columna',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RoutinesView(
              hasTracking: true,
              onManagementTap: () {},
              onStatusTap: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('sendaris-primary-app-bar')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('sendaris-primary-app-bar-logo')),
          findsOneWidget,
        );

        expect(find.text('Sendaris'), findsOneWidget);

        expect(find.text('Rutinas'), findsNWidgets(2));

        expect(find.text('Organiza y administra tus rutinas'), findsOneWidget);

        expect(
          find.text(
            'Selecciona una opción para gestionar '
            'las rutinas o registrar su estado.',
          ),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routines-management-option')),
          findsOneWidget,
        );

        expect(
          find.text(
            'Crea, consulta, edita o elimina '
            'las rutinas del seguimiento actual.',
          ),
          findsOneWidget,
        );

        expect(find.byKey(const Key('routines-status-option')), findsOneWidget);

        expect(find.text('Estados de rutina'), findsOneWidget);

        expect(
          find.text(
            'Registra y consulta el estado '
            'observado de las rutinas.',
          ),
          findsOneWidget,
        );

        final routinesCard = tester.getRect(
          find.byKey(const Key('routines-management-option')),
        );

        final statusCard = tester.getRect(
          find.byKey(const Key('routines-status-option')),
        );

        expect(routinesCard.left, closeTo(statusCard.left, 0.1));

        expect(routinesCard.right, closeTo(statusCard.right, 0.1));

        expect(statusCard.top, greaterThan(routinesCard.bottom));

        expect(
          find.byKey(const Key('routines-no-tracking-message')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'las dos opciones ejecutan sus acciones cuando existe seguimiento',
      (tester) async {
        var managementTapCount = 0;
        var statusTapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: RoutinesView(
              hasTracking: true,
              onManagementTap: () {
                managementTapCount += 1;
              },
              onStatusTap: () {
                statusTapCount += 1;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('routines-management-option')));

        await tester.pumpAndSettle();

        expect(managementTapCount, 1);

        await tester.tap(find.byKey(const Key('routines-status-option')));

        await tester.pumpAndSettle();

        expect(statusTapCount, 1);
      },
    );

    testWidgets(
      'sin seguimiento muestra aviso y mantiene deshabilitadas las opciones',
      (tester) async {
        var managementTapCount = 0;
        var statusTapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: RoutinesView(
              hasTracking: false,
              onManagementTap: () {
                managementTapCount += 1;
              },
              onStatusTap: () {
                statusTapCount += 1;
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routines-no-tracking-message')),
          findsOneWidget,
        );

        expect(
          find.text(
            'Crea o selecciona un seguimiento '
            'desde Inicio para gestionar rutinas.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('routines-management-option')));

        await tester.tap(find.byKey(const Key('routines-status-option')));

        await tester.pumpAndSettle();

        expect(managementTapCount, 0);

        expect(statusTapCount, 0);
      },
    );
  });
}
