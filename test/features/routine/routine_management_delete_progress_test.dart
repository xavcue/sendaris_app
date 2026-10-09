import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/views/routine_management_view.dart';

void main() {
  testWidgets(
    'muestra progreso únicamente en la rutina que se está eliminando',
    (tester) async {
      final deleteGate = Completer<void>();

      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-eliminar',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: 'rutina-conservar',
            anonymousId: 'anonimo',
            name: 'Rutina de lectura',
          ),
        ],
        deleteGate: deleteGate,
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

      await tester.tap(find.byKey(const Key('routine-menu-rutina-eliminar')));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar rutina?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-delete-routine')));

      await tester.pump();

      final deletingCard = find.byKey(
        const Key('routine-card-rutina-eliminar'),
      );

      final preservedCard = find.byKey(
        const Key('routine-card-rutina-conservar'),
      );

      expect(deletingCard, findsOneWidget);

      expect(preservedCard, findsOneWidget);

      expect(
        find.descendant(
          of: deletingCard,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: preservedCard,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      expect(
        find.byKey(const Key('routine-menu-rutina-eliminar')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('routine-menu-rutina-conservar')),
        findsOneWidget,
      );

      deleteGate.complete();

      await tester.pumpAndSettle();

      expect(repository.deletedRoutineId, 'rutina-eliminar');

      expect(
        find.byKey(const Key('routine-card-rutina-eliminar')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('routine-card-rutina-conservar')),
        findsOneWidget,
      );

      expect(find.text('Rutina eliminada correctamente.'), findsOneWidget);
    },
  );
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({
    required List<Routine> routines,
    required this.deleteGate,
  }) : routines = List<Routine>.of(routines);

  List<Routine> routines;

  final Completer<void> deleteGate;

  String? deletedRoutineId;

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
  }) async {
    await deleteGate.future;

    deletedRoutineId = routineId;

    routines = routines
        .where((routine) => routine.routineId != routineId)
        .toList(growable: false);
  }
}
