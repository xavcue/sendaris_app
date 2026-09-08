import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_id_generator.dart';
import 'package:sendaris/features/routine/presentation/views/routine_form_view.dart';

void main() {
  testWidgets(
    'muestra el formulario de creación con lenguaje orientado al usuario',
    (tester) async {
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

      expect(find.text('Crear rutina'), findsOneWidget);

      expect(
        find.text(
          'Define una actividad cotidiana para organizar la rutina del perfil activo.',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Registra una actividad habitual para el perfil activo.'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('routine-name-field')), findsOneWidget);

      expect(find.text('Sin recurrencia'), findsOneWidget);

      expect(find.text('Diaria'), findsOneWidget);

      expect(find.text('Semanal'), findsOneWidget);

      expect(find.text('Mensual'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;

      final profileMessage = find.byKey(const Key('routine-profile-message'));

      await tester.scrollUntilVisible(
        profileMessage,
        300,
        scrollable: scrollable,
      );

      expect(profileMessage, findsOneWidget);

      expect(
        find.text('La rutina se guardará en el perfil activo.'),
        findsOneWidget,
      );

      expect(find.textContaining('seguimiento anónimo'), findsNothing);

      expect(find.textContaining('identificador interno'), findsNothing);

      expect(find.textContaining('que quieras realizar'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('routine-save-button')),
        300,
        scrollable: scrollable,
      );

      expect(find.byKey(const Key('routine-save-button')), findsOneWidget);
    },
  );
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
