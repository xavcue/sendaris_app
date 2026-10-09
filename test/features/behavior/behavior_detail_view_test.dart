import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_detail_view.dart';

void main() {
  group('BehaviorDetailView', () {
    testWidgets(
      'muestra el patrón visual unificado y todos los datos registrados',
      (tester) async {
        final record = BehaviorRecord(
          recordId: 'registro-interno-123',
          anonymousId: 'seguimiento-interno-456',
          date: DateTime(2026, 9, 22),
          time: '19:49',
          category: BehaviorCategory.repetitiveBehavior,
          durationMinutes: 10,
          intensity: BehaviorIntensity.medium,
          context: 'Cambio de actividad',
          observation: 'Se repitió varias veces.',
          createdAt: DateTime.utc(2026, 9, 23, 0, 49),
          updatedAt: DateTime.utc(2026, 9, 23, 0, 49),
        );

        await _pumpDetail(tester, record);

        expect(find.text('Detalle de conducta'), findsOneWidget);

        expect(find.text('Registro de conducta'), findsOneWidget);

        expect(
          find.text('Consulta la información registrada para este evento.'),
          findsOneWidget,
        );

        expect(find.text('Conducta repetitiva'), findsOneWidget);

        expect(find.text('22 sep 2026 · 19:49'), findsOneWidget);

        expect(find.text('Fecha'), findsOneWidget);

        expect(find.text('22 sep 2026'), findsOneWidget);

        expect(find.text('Hora'), findsOneWidget);

        expect(find.text('19:49'), findsOneWidget);

        expect(find.text('Duración'), findsOneWidget);

        expect(find.text('10 min'), findsOneWidget);

        expect(find.text('Intensidad descriptiva'), findsOneWidget);

        expect(find.text('Media'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;

        await tester.scrollUntilVisible(
          find.text('Contexto general'),
          250,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        expect(find.text('Contexto general'), findsOneWidget);

        expect(find.text('Cambio de actividad'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Observación'),
          250,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        expect(find.text('Observación'), findsOneWidget);

        expect(find.text('Se repitió varias veces.'), findsOneWidget);

        expect(find.textContaining('registro-interno-123'), findsNothing);

        expect(find.textContaining('seguimiento-interno-456'), findsNothing);
      },
    );

    testWidgets(
      'presenta los campos opcionales ausentes con textos homogéneos',
      (tester) async {
        final record = BehaviorRecord(
          recordId: 'registro-1',
          anonymousId: 'seguimiento-1',
          date: DateTime(2026, 9, 20),
          category: BehaviorCategory.avoidanceFear,
          createdAt: DateTime.utc(2026, 9, 20, 18),
          updatedAt: DateTime.utc(2026, 9, 20, 18),
        );

        await _pumpDetail(tester, record);

        expect(find.text('20 sep 2026 · Sin hora'), findsOneWidget);

        expect(find.text('Sin hora'), findsOneWidget);

        expect(find.text('Sin duración'), findsOneWidget);

        expect(find.text('Sin intensidad'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;

        await tester.scrollUntilVisible(
          find.text('Sin contexto'),
          250,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        expect(find.text('Sin contexto'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Sin observación'),
          250,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        expect(find.text('Sin observación'), findsOneWidget);

        expect(find.text('No registrada'), findsNothing);

        expect(find.text('No registrado'), findsNothing);

        expect(find.textContaining('registro-1'), findsNothing);

        expect(find.textContaining('seguimiento-1'), findsNothing);
      },
    );
  });
}

Future<void> _pumpDetail(WidgetTester tester, BehaviorRecord record) async {
  await tester.binding.setSurfaceSize(const Size(500, 900));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(home: BehaviorDetailView(record: record)),
  );

  await tester.pumpAndSettle();
}
