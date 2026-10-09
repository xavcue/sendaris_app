import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/presentation/views/routine_status_detail_view.dart';

void main() {
  group('RoutineStatusDetailView', () {
    testWidgets('muestra la información descriptiva del estado de rutina', (
      tester,
    ) async {
      final record = RoutineStatusRecord(
        recordId: 'registro-interno-123',
        anonymousId: 'seguimiento-interno-456',
        routineId: 'rutina-interna-789',
        date: DateTime(2026, 9, 22),
        status: RoutineStatus.modified,
        observation: 'La rutina se realizó con un cambio en el horario.',
        createdAt: DateTime.utc(2026, 9, 22, 18),
        updatedAt: DateTime.utc(2026, 9, 22, 19),
      );

      await _pumpDetail(
        tester,
        record: record,
        routineName: 'Preparar mochila',
      );

      expect(
        find.byKey(const Key('routine-status-detail-view')),
        findsOneWidget,
      );

      expect(find.text('Detalle de estado de rutina'), findsOneWidget);

      expect(find.text('Estado de rutina'), findsOneWidget);

      expect(
        find.text('Consulta la información registrada para esta rutina.'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-detail-summary-card')),
        findsOneWidget,
      );

      expect(find.text('Rutina'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-status-detail-status-badge')),
        findsOneWidget,
      );

      expect(find.text('Modificada'), findsNWidgets(2));

      expect(find.text('Registro'), findsOneWidget);

      expect(find.text('Fecha'), findsOneWidget);

      expect(find.text('22 sep 2026'), findsOneWidget);

      expect(find.text('Estado'), findsOneWidget);

      expect(find.text('Información adicional'), findsOneWidget);

      expect(find.text('Observación'), findsOneWidget);

      expect(
        find.text('La rutina se realizó con un cambio en el horario.'),
        findsOneWidget,
      );

      expect(find.textContaining('registro-interno-123'), findsNothing);

      expect(find.textContaining('seguimiento-interno-456'), findsNothing);

      expect(find.textContaining('rutina-interna-789'), findsNothing);

      expect(find.textContaining('2026-09-22 18'), findsNothing);

      expect(find.textContaining('2026-09-22 19'), findsNothing);
    });

    testWidgets('muestra texto seguro cuando no existe observación', (
      tester,
    ) async {
      final record = RoutineStatusRecord(
        recordId: 'registro-1',
        anonymousId: 'seguimiento-1',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 20),
        status: RoutineStatus.completed,
        createdAt: DateTime.utc(2026, 9, 20, 18),
        updatedAt: DateTime.utc(2026, 9, 20, 18),
      );

      await _pumpDetail(
        tester,
        record: record,
        routineName: 'Rutina de mañana',
      );

      expect(find.text('Rutina de mañana'), findsOneWidget);

      expect(find.text('Completada'), findsNWidgets(2));

      expect(find.text('20 sep 2026'), findsOneWidget);

      expect(find.text('Sin observación'), findsOneWidget);

      expect(find.textContaining('registro-1'), findsNothing);

      expect(find.textContaining('seguimiento-1'), findsNothing);
    });

    testWidgets(
      'muestra Rutina no disponible cuando el nombre no puede resolverse',
      (tester) async {
        final record = RoutineStatusRecord(
          recordId: 'registro-huerfano',
          anonymousId: 'seguimiento-1',
          routineId: 'rutina-eliminada',
          date: DateTime(2026, 9, 18),
          status: RoutineStatus.interrupted,
          observation: 'Se interrumpió antes de finalizar.',
          createdAt: DateTime.utc(2026, 9, 18, 18),
          updatedAt: DateTime.utc(2026, 9, 18, 18),
        );

        await _pumpDetail(tester, record: record, routineName: '   ');

        expect(find.text('Rutina no disponible'), findsOneWidget);

        expect(find.text('Interrumpida'), findsNWidgets(2));

        expect(find.text('18 sep 2026'), findsOneWidget);

        expect(find.text('Se interrumpió antes de finalizar.'), findsOneWidget);

        expect(find.textContaining('rutina-eliminada'), findsNothing);
      },
    );

    testWidgets('representa correctamente el estado No realizada', (
      tester,
    ) async {
      final record = RoutineStatusRecord(
        recordId: 'registro-no-realizado',
        anonymousId: 'seguimiento-1',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 17),
        status: RoutineStatus.notCompleted,
        observation: 'No fue posible realizarla.',
        createdAt: DateTime.utc(2026, 9, 17, 18),
        updatedAt: DateTime.utc(2026, 9, 17, 18),
      );

      await _pumpDetail(
        tester,
        record: record,
        routineName: 'Preparar materiales',
      );

      expect(find.text('Preparar materiales'), findsOneWidget);

      expect(find.text('No realizada'), findsNWidgets(2));

      expect(find.text('17 sep 2026'), findsOneWidget);

      expect(find.text('No fue posible realizarla.'), findsOneWidget);
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required RoutineStatusRecord record,
  required String routineName,
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 900));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: RoutineStatusDetailView(record: record, routineName: routineName),
    ),
  );

  await tester.pumpAndSettle();
}
