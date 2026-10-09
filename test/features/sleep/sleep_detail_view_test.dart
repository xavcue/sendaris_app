import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/presentation/views/sleep_detail_view.dart';

void main() {
  group('SleepDetailView', () {
    testWidgets(
      'muestra el patrón visual unificado cuando el sueño termina al día siguiente',
      (tester) async {
        final record = SleepRecord(
          recordId: 'sueno-interno-123',
          anonymousId: 'seguimiento-interno-456',
          date: DateTime(2026, 9, 22),
          startTime: '22:00',
          endTime: '06:00',
          durationMinutes: 480,
          observation: 'Descanso continuo.',
          createdAt: DateTime.utc(2026, 9, 23, 8),
          updatedAt: DateTime.utc(2026, 9, 23, 8),
        );

        await _pumpDetail(tester, record);

        expect(find.text('Detalle de sueño'), findsOneWidget);

        expect(find.text('Registro de sueño'), findsOneWidget);

        expect(
          find.text('Consulta la información registrada para este evento.'),
          findsOneWidget,
        );

        expect(find.text('22:00 – 06:00'), findsOneWidget);

        expect(find.text('22 sep 2026 – 23 sep 2026'), findsNWidgets(2));

        expect(find.text('Periodo de fechas'), findsOneWidget);

        expect(find.text('Hora de inicio'), findsOneWidget);

        expect(find.text('22:00'), findsOneWidget);

        expect(find.text('Hora de finalización'), findsOneWidget);

        expect(find.text('06:00'), findsOneWidget);

        expect(find.text('Duración'), findsOneWidget);

        expect(find.text('8 h'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;

        await tester.scrollUntilVisible(
          find.text('Observación'),
          250,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        expect(find.text('Observación'), findsOneWidget);

        expect(find.text('Descanso continuo.'), findsOneWidget);

        expect(find.textContaining('sueno-interno-123'), findsNothing);

        expect(find.textContaining('seguimiento-interno-456'), findsNothing);
      },
    );

    testWidgets('muestra una sola fecha cuando inicia y termina el mismo día', (
      tester,
    ) async {
      final record = SleepRecord(
        recordId: 'sueno-diurno',
        anonymousId: 'seguimiento-1',
        date: DateTime(2026, 9, 20),
        startTime: '14:00',
        endTime: '16:30',
        durationMinutes: 150,
        createdAt: DateTime.utc(2026, 9, 20, 20),
        updatedAt: DateTime.utc(2026, 9, 20, 20),
      );

      await _pumpDetail(tester, record);

      expect(find.text('14:00 – 16:30'), findsOneWidget);

      expect(find.text('20 sep 2026'), findsNWidgets(2));

      expect(find.textContaining('21 sep 2026'), findsNothing);

      expect(find.text('2 h 30 min'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.text('Sin observación'),
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      expect(find.text('Sin observación'), findsOneWidget);

      expect(find.text('No registrada'), findsNothing);
    });

    testWidgets('mantiene correctamente un periodo nocturno sin observación', (
      tester,
    ) async {
      final record = SleepRecord(
        recordId: 'sueno-1',
        anonymousId: 'seguimiento-1',
        date: DateTime(2026, 9, 20),
        startTime: '23:30',
        endTime: '07:00',
        durationMinutes: 450,
        createdAt: DateTime.utc(2026, 9, 21, 8),
        updatedAt: DateTime.utc(2026, 9, 21, 8),
      );

      await _pumpDetail(tester, record);

      expect(find.text('20 sep 2026 – 21 sep 2026'), findsNWidgets(2));

      expect(find.text('23:30 – 07:00'), findsOneWidget);

      expect(find.text('7 h 30 min'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.text('Sin observación'),
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      expect(find.text('Sin observación'), findsOneWidget);

      expect(find.textContaining('sueno-1'), findsNothing);

      expect(find.textContaining('seguimiento-1'), findsNothing);
    });
  });
}

Future<void> _pumpDetail(WidgetTester tester, SleepRecord record) async {
  await tester.binding.setSurfaceSize(const Size(500, 900));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(MaterialApp(home: SleepDetailView(record: record)));

  await tester.pumpAndSettle();
}
