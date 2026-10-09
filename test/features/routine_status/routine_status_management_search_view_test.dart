import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/presentation/views/routine_status_management_view.dart';

void main() {
  group('RoutineStatusManagementView búsqueda', () {
    testWidgets('muestra el buscador y todas las rutinas inicialmente', (
      tester,
    ) async {
      await _pumpView(tester);

      expect(
        find.byKey(const Key('routine-status-routine-search-field')),
        findsOneWidget,
      );

      expect(find.text('Buscar rutina por nombre'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Rutina de lectura'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-status-clear-routine-search')),
        findsNothing,
      );

      final countFinder = find.byKey(const Key('routine-status-routine-count'));

      expect(
        find.descendant(of: countFinder, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('filtra por nombre y muestra contador de resultados', (
      tester,
    ) async {
      await _pumpView(tester);

      await tester.enterText(
        find.byKey(const Key('routine-status-routine-search-field')),
        'mochi',
      );

      await tester.pump();

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsNothing);

      expect(find.text('Rutina de lectura'), findsNothing);

      expect(
        find.byKey(const Key('routine-status-clear-routine-search')),
        findsOneWidget,
      );

      final countFinder = find.byKey(const Key('routine-status-routine-count'));

      expect(
        find.descendant(of: countFinder, matching: find.text('1 de 3')),
        findsOneWidget,
      );
    });

    testWidgets('la búsqueda visual también ignora tildes', (tester) async {
      await _pumpView(tester);

      await tester.enterText(
        find.byKey(const Key('routine-status-routine-search-field')),
        'alimentacion',
      );

      await tester.pump();

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsNothing);

      expect(find.text('Rutina de lectura'), findsNothing);
    });

    testWidgets(
      'sin coincidencias muestra estado vacío de búsqueda y permite limpiar',
      (tester) async {
        await _pumpView(tester);

        final searchField = find.byKey(
          const Key('routine-status-routine-search-field'),
        );

        await tester.enterText(searchField, 'rutina inexistente');

        await tester.pump();

        expect(
          find.byKey(const Key('routine-status-no-routine-search-results')),
          findsOneWidget,
        );

        expect(find.text('No se encontraron rutinas'), findsOneWidget);

        expect(
          find.text(
            'No hay rutinas que coincidan con '
            '“rutina inexistente”.',
          ),
          findsOneWidget,
        );

        expect(find.text('Preparar mochila'), findsNothing);

        final countFinder = find.byKey(
          const Key('routine-status-routine-count'),
        );

        expect(
          find.descendant(of: countFinder, matching: find.text('0 de 3')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('routine-status-clear-empty-search')),
        );

        await tester.pump();

        expect(
          find.byKey(const Key('routine-status-no-routine-search-results')),
          findsNothing,
        );

        expect(find.text('Preparar mochila'), findsOneWidget);

        expect(find.text('Alimentación de la mañana'), findsOneWidget);

        expect(find.text('Rutina de lectura'), findsOneWidget);

        final field = tester.widget<TextField>(searchField);

        expect(field.controller?.text, isEmpty);
      },
    );

    testWidgets('la equis limpia la búsqueda y restaura todas las rutinas', (
      tester,
    ) async {
      await _pumpView(tester);

      await tester.enterText(
        find.byKey(const Key('routine-status-routine-search-field')),
        'lectura',
      );

      await tester.pump();

      expect(find.text('Rutina de lectura'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsNothing);

      await tester.tap(
        find.byKey(const Key('routine-status-clear-routine-search')),
      );

      await tester.pump();

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Rutina de lectura'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-status-clear-routine-search')),
        findsNothing,
      );
    });
  });
}

Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2200);

  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final statusRepository = _FakeRoutineStatusManagementRepository(
    records: [
      _record(
        recordId: 'estado-mochila',
        routineId: 'rutina-mochila',
        date: DateTime(2026, 10, 1),
      ),
      _record(
        recordId: 'estado-alimentacion',
        routineId: 'rutina-alimentacion',
        date: DateTime(2026, 9, 30),
      ),
      _record(
        recordId: 'estado-lectura',
        routineId: 'rutina-lectura',
        date: DateTime(2026, 9, 29),
      ),
    ],
  );

  final routineRepository = _FakeRoutineRepository(
    routines: const [
      Routine(
        routineId: 'rutina-mochila',
        anonymousId: 'seguimiento-actual',
        name: 'Preparar mochila',
      ),
      Routine(
        routineId: 'rutina-alimentacion',
        anonymousId: 'seguimiento-actual',
        name: 'Alimentación de la mañana',
      ),
      Routine(
        routineId: 'rutina-lectura',
        anonymousId: 'seguimiento-actual',
        name: 'Rutina de lectura',
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp(
      home: RoutineStatusManagementView(
        repository: statusRepository,
        routineRepository: routineRepository,
        anonymousId: 'seguimiento-actual',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
}) {
  final timestamp = DateTime.utc(2026, 10, 1, 18);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    routineId: routineId,
    date: date,
    status: RoutineStatus.completed,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeRoutineStatusManagementRepository
    implements RoutineStatusManagementRepository {
  _FakeRoutineStatusManagementRepository({required this.records});

  final List<RoutineStatusRecord> records;

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return List.unmodifiable(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({required this.routines});

  final List<Routine> routines;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return List.unmodifiable(routines);
  }

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
