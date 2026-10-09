import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/views/routine_management_view.dart';

void main() {
  group('RoutineManagementView', () {
    testWidgets(
      'muestra la gestión de rutinas con el patrón visual de Eventos',
      (tester) async {
        final repository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: '1',
              anonymousId: 'anonimo',
              name: 'Preparar mochila',
              description: 'Revisar los materiales.',
              scheduledTime: '20:00',
              recurrence: 'diaria',
            ),
            Routine(
              routineId: '2',
              anonymousId: 'anonimo',
              name: 'Rutina de lectura',
            ),
          ],
        );

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-management-view')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-management-title')),
          findsOneWidget,
        );

        expect(find.text('Gestión de rutinas'), findsOneWidget);

        expect(
          find.text('Consulta y administra las rutinas registradas.'),
          findsOneWidget,
        );

        expect(
          find.text(
            'Puedes crear, consultar, editar o eliminar '
            'las rutinas del seguimiento actual.',
          ),
          findsOneWidget,
        );

        expect(find.byKey(const Key('routine-create-button')), findsOneWidget);

        expect(find.text('Nueva rutina'), findsOneWidget);

        expect(find.text('Preparar mochila'), findsOneWidget);

        expect(find.text('Rutina de lectura'), findsOneWidget);

        expect(find.text('Revisar los materiales.'), findsOneWidget);

        expect(find.text('20:00'), findsOneWidget);

        expect(find.text('Diaria'), findsOneWidget);

        final countFinder = find.byKey(const Key('routine-count'));

        expect(countFinder, findsOneWidget);

        expect(
          find.descendant(of: countFinder, matching: find.text('2')),
          findsOneWidget,
        );

        final countContainer = tester.widget<Container>(countFinder);

        final decoration = countContainer.decoration! as BoxDecoration;

        final countContext = tester.element(countFinder);

        final colorScheme = Theme.of(countContext).colorScheme;

        expect(
          decoration.color,
          colorScheme.primaryContainer.withValues(alpha: 0.62),
        );
      },
    );

    testWidgets('tocar una rutina utiliza la ruta canónica de detalle', (
      tester,
    ) async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
            scheduledTime: '18:05',
            recurrence: 'diaria',
          ),
        ],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('routine-open-rutina-test')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.routineDetail);

      expect(find.byKey(const Key('test-routine-detail')), findsOneWidget);
    });

    testWidgets('Nueva rutina utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: '1',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
          ),
        ],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('routine-create-button')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.routineNew);

      expect(find.byKey(const Key('test-routine-new')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-routine-new')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.routineManagement);

      expect(repository.recoveryCount, 2);
    });

    testWidgets('el menú de una rutina ofrece Editar y Eliminar', (
      tester,
    ) async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: 'anonimo',
            name: 'Rutina de lectura',
          ),
        ],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('routine-menu-rutina-test')));

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('Editar utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: 'anonimo',
            name: 'Rutina de lectura',
          ),
        ],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('routine-menu-rutina-test')));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.routineEdit);

      expect(find.byKey(const Key('test-routine-edit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-routine-edit')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.routineManagement);

      expect(repository.recoveryCount, 2);
    });

    testWidgets(
      'eliminar advierte la eliminación de estados y retira la rutina',
      (tester) async {
        final repository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-test',
              anonymousId: 'anonimo',
              name: 'Preparar mochila',
            ),
            Routine(
              routineId: 'rutina-lectura',
              anonymousId: 'anonimo',
              name: 'Rutina de lectura',
            ),
          ],
        );

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('routine-menu-rutina-test')));

        await tester.pumpAndSettle();

        await tester.tap(find.text('Eliminar'));

        await tester.pumpAndSettle();

        expect(find.text('¿Eliminar rutina?'), findsOneWidget);

        expect(
          find.textContaining('todos los estados registrados para esta rutina'),
          findsOneWidget,
        );

        expect(
          find.textContaining('Esta acción no se puede deshacer.'),
          findsOneWidget,
        );

        expect(find.text('Eliminar definitivamente'), findsOneWidget);

        await tester.tap(find.byKey(const Key('confirm-delete-routine')));

        await tester.pumpAndSettle();

        expect(repository.deletedAnonymousId, 'anonimo');

        expect(repository.deletedRoutineId, 'rutina-test');

        expect(find.text('Preparar mochila'), findsNothing);

        expect(find.text('Rutina de lectura'), findsOneWidget);

        expect(find.text('Rutina eliminada correctamente.'), findsOneWidget);

        expect(
          find.descendant(
            of: find.byKey(const Key('routine-count')),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('muestra estado vacío cuando no existen rutinas', (
      tester,
    ) async {
      final repository = _FakeRoutineRepository(routines: const []);

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routine-empty-state')), findsOneWidget);

      expect(find.text('Aún no hay rutinas'), findsOneWidget);

      expect(find.text('Las nuevas rutinas aparecerán aquí.'), findsOneWidget);

      expect(find.byKey(const Key('routine-create-button')), findsOneWidget);
    });
  });
}

GoRouter _createRouter(_FakeRoutineRepository repository) {
  return GoRouter(
    initialLocation: AppRoutes.routineManagement,
    routes: [
      GoRoute(
        path: AppRoutes.routineManagement,
        builder: (context, state) {
          return RoutineManagementView(
            repository: repository,
            anonymousId: 'anonimo',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.routineDetail,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-routine-detail'),
            body: Center(child: Text('Detalle de rutina')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.routineNew,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-routine-new'),
            body: Center(
              child: FilledButton(
                key: const Key('close-routine-new'),
                onPressed: () {
                  context.pop(true);
                },
                child: const Text('Cerrar nueva rutina'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.routineEdit,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-routine-edit'),
            body: Center(
              child: FilledButton(
                key: const Key('close-routine-edit'),
                onPressed: () {
                  context.pop(true);
                },
                child: const Text('Cerrar edición'),
              ),
            ),
          );
        },
      ),
    ],
  );
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({required List<Routine> routines})
    : routines = List<Routine>.of(routines);

  List<Routine> routines;

  int recoveryCount = 0;

  String? deletedAnonymousId;
  String? deletedRoutineId;

  @override
  Future<void> createRoutine(Routine routine) async {
    routines.add(routine);
  }

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    recoveryCount += 1;

    return List.unmodifiable(routines);
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    final index = routines.indexWhere(
      (current) => current.routineId == routine.routineId,
    );

    if (index >= 0) {
      routines[index] = routine;
    }
  }

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    deletedAnonymousId = anonymousId;
    deletedRoutineId = routineId;

    routines = routines
        .where((routine) => routine.routineId != routineId)
        .toList();
  }
}
