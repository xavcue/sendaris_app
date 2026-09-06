import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/views/routine_management_view.dart';

void main() {
  testWidgets('muestra rutinas activas y desactivadas', (tester) async {
    final repository = _FakeRoutineRepository(
      routines: const [
        Routine(
          routineId: '1',
          anonymousId: 'anonimo',
          name: 'Preparar mochila',
          scheduledTime: '20:00',
          recurrence: 'diaria',
          isActive: true,
        ),
        Routine(
          routineId: '2',
          anonymousId: 'anonimo',
          name: 'Rutina anterior',
          isActive: false,
        ),
      ],
    );

    final router = GoRouter(
      initialLocation: '/routines',
      routes: [
        GoRoute(
          path: '/routines',
          builder: (_, _) => RoutineManagementView(
            repository: repository,
            anonymousId: 'anonimo',
          ),
        ),
        GoRoute(path: '/routines/new', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/routines/edit', builder: (_, _) => const Scaffold()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    expect(find.text('Preparar mochila'), findsOneWidget);

    expect(find.text('Diaria'), findsOneWidget);

    expect(find.text('20:00'), findsOneWidget);

    expect(find.textContaining('Rutinas desactivadas'), findsOneWidget);

    expect(find.byKey(const Key('routine-create-button')), findsOneWidget);
  });
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({required this.routines});

  final List<Routine> routines;

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return routines;
  }

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
