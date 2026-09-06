import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_id_generator.dart';
import 'package:sendaris/features/routine/presentation/views/routine_form_view.dart';

void main() {
  testWidgets('muestra el formulario de creación de rutina', (tester) async {
    final router = GoRouter(
      initialLocation: '/routines/new',
      routes: [
        GoRoute(
          path: '/routines/new',
          builder: (_, _) => RoutineFormView(
            repository: _FakeRoutineRepository(),
            routineFactory: const RoutineFactory(_FakeRoutineIdGenerator()),
            anonymousId: 'anonimo-test',
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    expect(find.text('Nueva rutina'), findsOneWidget);

    expect(find.byKey(const Key('routine-name-field')), findsOneWidget);

    expect(find.text('Sin recurrencia'), findsOneWidget);

    expect(find.text('Diaria'), findsOneWidget);

    expect(find.text('Semanal'), findsOneWidget);

    expect(find.text('Mensual'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routine-save-button')), findsOneWidget);
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
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
