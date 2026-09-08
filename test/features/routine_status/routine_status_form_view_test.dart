import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_repository.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_id_generator.dart';
import 'package:sendaris/features/routine_status/presentation/views/routine_status_form_view.dart';

void main() {
  Widget createSubject({List<Routine> routines = const []}) {
    return MaterialApp(
      home: RoutineStatusFormView(
        routineRepository: _FakeRoutineRepository(routines),
        routineStatusRepository: _FakeRoutineStatusRepository(),
        recordFactory: const RoutineStatusRecordFactory(
          _FakeRoutineStatusRecordIdGenerator(),
        ),
        anonymousId: 'anonimo-test',
      ),
    );
  }

  testWidgets(
    'muestra únicamente rutinas activas con lenguaje orientado al usuario',
    (tester) async {
      await tester.pumpWidget(
        createSubject(
          routines: const [
            Routine(
              routineId: 'rutina-activa',
              anonymousId: 'anonimo-test',
              name: 'Preparar mochila',
              isActive: true,
            ),
            Routine(
              routineId: 'rutina-inactiva',
              anonymousId: 'anonimo-test',
              name: 'Rutina desactivada',
              isActive: false,
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Registrar estado de rutina'), findsOneWidget);

      expect(find.text('Estado de una rutina'), findsOneWidget);

      expect(
        find.text('Elige una rutina activa para registrar su estado.'),
        findsOneWidget,
      );

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Rutina desactivada'), findsNothing);

      expect(find.textContaining('seguimiento anónimo'), findsNothing);

      expect(find.textContaining('identificador interno'), findsNothing);

      final scrollable = find.byType(Scrollable).first;

      final profileMessage = find.byKey(
        const Key('routine-status-profile-message'),
      );

      await tester.scrollUntilVisible(
        profileMessage,
        300,
        scrollable: scrollable,
      );

      expect(profileMessage, findsOneWidget);

      expect(
        find.text('La información se guardará en el perfil activo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('muestra mensaje cuando no existen rutinas activas', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routine-status-no-routines')), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));

    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('routine-status-save-button')),
    );

    expect(saveButton.onPressed, isNull);
  });

  testWidgets('permite seleccionar rutina y estado', (tester) async {
    await tester.pumpWidget(
      createSubject(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: 'anonimo-test',
            name: 'Preparar mochila',
            isActive: true,
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('routine-status-routine-rutina-test')),
    );

    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -500));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('routine-status-completada')));

    await tester.pump();

    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('routine-status-completada')),
    );

    expect(chip.selected, isTrue);
  });
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository(this.routines);

  final List<Routine> routines;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return routines;
  }

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}

class _FakeRoutineStatusRepository implements RoutineStatusRepository {
  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return const [];
  }
}

class _FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const _FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'routine-status-test-id';
  }
}
