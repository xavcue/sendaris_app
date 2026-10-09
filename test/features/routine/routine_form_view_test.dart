import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_id_generator.dart';
import 'package:sendaris/features/routine/presentation/views/routine_form_view.dart';

void main() {
  group('RoutineFormView', () {
    testWidgets('muestra Registrar rutina con la nomenclatura normalizada', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoutineFormView(
            repository: _FakeRoutineRepository(),
            routineFactory: const RoutineFactory(_FakeRoutineIdGenerator()),
            anonymousId: 'anonimo-test',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routine-form-view')), findsOneWidget);

      expect(find.text('Registrar rutina'), findsOneWidget);

      expect(find.text('Registro de rutina'), findsOneWidget);

      expect(
        find.text(
          'Define una actividad habitual '
          'para organizar las rutinas '
          'del seguimiento actual.',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'La rutina se guardará en el '
          'seguimiento actual.',
        ),
        findsOneWidget,
      );

      expect(find.text('Nombre de la rutina'), findsOneWidget);

      expect(find.text('Obligatorio'), findsOneWidget);

      expect(find.text('Descripción (opcional)'), findsOneWidget);

      expect(find.text('Programación (opcional)'), findsOneWidget);

      expect(find.byKey(const Key('routine-name-field')), findsOneWidget);

      expect(
        find.byKey(const Key('routine-description-field')),
        findsOneWidget,
      );

      expect(find.text('Sin hora'), findsOneWidget);

      expect(find.text('Frecuencia (opcional)'), findsOneWidget);

      expect(find.text('Diaria'), findsOneWidget);

      expect(find.text('Semanal'), findsOneWidget);

      expect(find.text('Mensual'), findsOneWidget);

      expect(find.text('Sin recurrencia'), findsNothing);

      expect(find.textContaining('Activa'), findsNothing);

      expect(find.textContaining('Inactiva'), findsNothing);

      expect(find.textContaining('Activar'), findsNothing);

      expect(find.textContaining('Desactivar'), findsNothing);

      expect(find.byKey(const Key('routine-save-button')), findsOneWidget);

      expect(find.text('Guardar rutina'), findsOneWidget);
    });

    testWidgets(
      'una frecuencia opcional puede seleccionarse y deseleccionarse',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RoutineFormView(
              repository: _FakeRoutineRepository(),
              routineFactory: const RoutineFactory(_FakeRoutineIdGenerator()),
              anonymousId: 'anonimo-test',
            ),
          ),
        );

        await tester.pumpAndSettle();

        final dailyFinder = find.byKey(const Key('routine-recurrence-daily'));

        final scrollable = find.byType(Scrollable).first;

        await tester.scrollUntilVisible(
          dailyFinder,
          300,
          scrollable: scrollable,
        );

        expect(tester.widget<ChoiceChip>(dailyFinder).selected, isFalse);

        await tester.tap(dailyFinder);

        await tester.pump();

        expect(tester.widget<ChoiceChip>(dailyFinder).selected, isTrue);

        await tester.tap(dailyFinder);

        await tester.pump();

        expect(tester.widget<ChoiceChip>(dailyFinder).selected, isFalse);
      },
    );

    testWidgets('Editar registro de rutina inicializa los datos existentes', (
      tester,
    ) async {
      const routine = Routine(
        routineId: 'rutina-1',
        anonymousId: 'anonimo-test',
        name: 'Preparar mochila',
        description: 'Revisar los materiales.',
        scheduledTime: '18:05',
        recurrence: 'diaria',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RoutineFormView(
            repository: _FakeRoutineRepository(),
            routineFactory: const RoutineFactory(_FakeRoutineIdGenerator()),
            anonymousId: 'anonimo-test',
            initialRoutine: routine,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Editar registro de rutina'), findsOneWidget);

      expect(find.text('Actualizar registro de rutina'), findsOneWidget);

      expect(
        find.text(
          'Revisa y modifica únicamente '
          'la información necesaria de la rutina.',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Los cambios se aplicarán a la '
          'rutina del seguimiento actual.',
        ),
        findsOneWidget,
      );

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('routine-name-field')),
      );

      expect(nameField.controller?.text, 'Preparar mochila');

      final descriptionField = tester.widget<TextField>(
        find.byKey(const Key('routine-description-field')),
      );

      expect(descriptionField.controller?.text, 'Revisar los materiales.');

      expect(find.text('18:05'), findsOneWidget);

      final dailyChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('routine-recurrence-daily')),
      );

      expect(dailyChip.selected, isTrue);

      expect(find.byKey(const Key('routine-save-button')), findsOneWidget);

      expect(find.text('Guardar cambios'), findsOneWidget);
    });

    testWidgets('el nombre obligatorio muestra validación temporal', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoutineFormView(
            repository: _FakeRoutineRepository(),
            routineFactory: const RoutineFactory(_FakeRoutineIdGenerator()),
            anonymousId: 'anonimo-test',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.byKey(const Key('routine-save-button')),
        300,
        scrollable: scrollable,
      );

      await tester.tap(find.byKey(const Key('routine-save-button')));

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('El nombre de la rutina es obligatorio.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));

      expect(find.text('El nombre de la rutina es obligatorio.'), findsNothing);
    });
  });
}

class _FakeRoutineIdGenerator implements RoutineIdGenerator {
  const _FakeRoutineIdGenerator();

  @override
  String generate() {
    return 'routine-test-id';
  }
}

class _FakeRoutineRepository implements RoutineRepository {
  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return [];
  }

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
