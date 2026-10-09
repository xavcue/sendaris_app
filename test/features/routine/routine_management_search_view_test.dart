import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/views/routine_management_view.dart';

void main() {
  group('RoutineManagementView búsqueda', () {
    testWidgets('muestra el buscador y todas las rutinas inicialmente', (
      tester,
    ) async {
      await _pumpView(tester);

      expect(find.byKey(const Key('routine-search-field')), findsOneWidget);

      expect(find.text('Buscar rutina por nombre'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Rutina de lectura'), findsOneWidget);

      expect(find.byKey(const Key('routine-clear-search')), findsNothing);

      final countFinder = find.byKey(const Key('routine-count'));

      expect(
        find.descendant(of: countFinder, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('filtra por nombre y actualiza el contador', (tester) async {
      await _pumpView(tester);

      await tester.enterText(
        find.byKey(const Key('routine-search-field')),
        'mochi',
      );

      await tester.pump();

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsNothing);

      expect(find.text('Rutina de lectura'), findsNothing);

      expect(find.byKey(const Key('routine-clear-search')), findsOneWidget);

      final countFinder = find.byKey(const Key('routine-count'));

      expect(
        find.descendant(of: countFinder, matching: find.text('1 de 3')),
        findsOneWidget,
      );
    });

    testWidgets('la búsqueda visual ignora tildes', (tester) async {
      await _pumpView(tester);

      await tester.enterText(
        find.byKey(const Key('routine-search-field')),
        'alimentacion',
      );

      await tester.pump();

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsNothing);

      expect(find.text('Rutina de lectura'), findsNothing);
    });

    testWidgets('sin coincidencias muestra estado vacío de búsqueda', (
      tester,
    ) async {
      await _pumpView(tester);

      final searchField = find.byKey(const Key('routine-search-field'));

      await tester.enterText(searchField, 'rutina inexistente');

      await tester.pump();

      expect(
        find.byKey(const Key('routine-no-search-results')),
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

      final countFinder = find.byKey(const Key('routine-count'));

      expect(
        find.descendant(of: countFinder, matching: find.text('0 de 3')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('routine-clear-empty-search')));

      await tester.pump();

      expect(find.byKey(const Key('routine-no-search-results')), findsNothing);

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Rutina de lectura'), findsOneWidget);

      final textField = tester.widget<TextField>(searchField);

      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('la equis limpia la búsqueda y restaura todas las rutinas', (
      tester,
    ) async {
      await _pumpView(tester);

      await tester.enterText(
        find.byKey(const Key('routine-search-field')),
        'lectura',
      );

      await tester.pump();

      expect(find.text('Rutina de lectura'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsNothing);

      await tester.tap(find.byKey(const Key('routine-clear-search')));

      await tester.pump();

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Alimentación de la mañana'), findsOneWidget);

      expect(find.text('Rutina de lectura'), findsOneWidget);

      expect(find.byKey(const Key('routine-clear-search')), findsNothing);

      final countFinder = find.byKey(const Key('routine-count'));

      expect(
        find.descendant(of: countFinder, matching: find.text('3')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);

  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final repository = _FakeRoutineRepository(
    routines: const [
      Routine(
        routineId: 'rutina-mochila',
        anonymousId: 'anonimo',
        name: 'Preparar mochila',
        description: 'Revisar los materiales.',
        scheduledTime: '20:00',
        recurrence: 'diaria',
      ),
      Routine(
        routineId: 'rutina-alimentacion',
        anonymousId: 'anonimo',
        name: 'Alimentación de la mañana',
      ),
      Routine(
        routineId: 'rutina-lectura',
        anonymousId: 'anonimo',
        name: 'Rutina de lectura',
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp(
      home: RoutineManagementView(
        repository: repository,
        anonymousId: 'anonimo',
      ),
    ),
  );

  await tester.pumpAndSettle();
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
