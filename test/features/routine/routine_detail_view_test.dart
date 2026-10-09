import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/presentation/views/routine_detail_view.dart';

void main() {
  group('RoutineDetailView', () {
    testWidgets('muestra únicamente la información descriptiva de la rutina', (
      tester,
    ) async {
      const routine = Routine(
        routineId: 'rutina-interna-123',
        anonymousId: 'seguimiento-interno-456',
        name: 'Preparar mochila',
        description: 'Revisar los materiales para el día siguiente.',
        scheduledTime: '18:05',
        recurrence: 'diaria',
      );

      await tester.pumpWidget(
        const MaterialApp(home: RoutineDetailView(routine: routine)),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routine-detail-view')), findsOneWidget);

      expect(find.text('Detalle de rutina'), findsOneWidget);

      expect(find.text('Rutina'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Programación'), findsOneWidget);

      expect(find.text('Hora programada'), findsOneWidget);

      expect(find.text('18:05'), findsOneWidget);

      expect(find.text('Frecuencia'), findsOneWidget);

      expect(find.text('Diaria'), findsOneWidget);

      expect(find.text('Información adicional'), findsOneWidget);

      expect(find.text('Descripción'), findsOneWidget);

      expect(
        find.text('Revisar los materiales para el día siguiente.'),
        findsOneWidget,
      );

      expect(find.textContaining('rutina-interna-123'), findsNothing);

      expect(find.textContaining('seguimiento-interno-456'), findsNothing);

      expect(find.textContaining('Activa'), findsNothing);

      expect(find.textContaining('Inactiva'), findsNothing);

      expect(find.textContaining('Desactivar'), findsNothing);

      expect(find.textContaining('Activar'), findsNothing);
    });

    testWidgets(
      'muestra textos seguros cuando los campos opcionales no existen',
      (tester) async {
        const routine = Routine(
          routineId: 'rutina-simple',
          anonymousId: 'seguimiento-1',
          name: 'Ordenar escritorio',
        );

        await tester.pumpWidget(
          const MaterialApp(home: RoutineDetailView(routine: routine)),
        );

        await tester.pumpAndSettle();

        expect(find.text('Ordenar escritorio'), findsOneWidget);

        expect(find.text('Sin hora'), findsOneWidget);

        expect(find.text('Sin recurrencia'), findsOneWidget);

        expect(find.text('No registrada'), findsOneWidget);
      },
    );
  });
}
