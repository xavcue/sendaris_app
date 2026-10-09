import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_management_repository.dart';
import 'package:sendaris/features/social_interaction/presentation/viewmodels/social_interaction_management_view_model.dart';
import 'package:sendaris/features/social_interaction/presentation/views/social_interaction_management_view.dart';

void main() {
  group('SocialInteractionManagementView', () {
    testWidgets('muestra gestión con Nuevo registro y contador coloreado', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      expect(
        find.text('Gestión de registros de interacción social'),
        findsOneWidget,
      );

      expect(find.text('Intercambio social'), findsOneWidget);

      expect(find.text('22 sep 2026'), findsOneWidget);

      expect(find.text('Contexto: Actividad recreativa'), findsOneWidget);

      expect(find.text('Observación: Registro ficticio.'), findsOneWidget);

      expect(
        find.byKey(const Key('social-interaction-new-record-button')),
        findsOneWidget,
      );

      expect(find.text('Nuevo registro'), findsOneWidget);

      final countFinder = find.byKey(
        const Key('social-interaction-record-count'),
      );

      expect(countFinder, findsOneWidget);

      final countContainer = tester.widget<Container>(countFinder);

      final decoration = countContainer.decoration! as BoxDecoration;

      final countContext = tester.element(countFinder);

      final colorScheme = Theme.of(countContext).colorScheme;

      expect(
        decoration.color,
        colorScheme.primaryContainer.withValues(alpha: 0.62),
      );
    });

    testWidgets('el filtro inicia contraído y puede expandirse y contraerse', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('social-interaction-filter-toggle')),
        findsOneWidget,
      );

      expect(find.text('Filtrar'), findsOneWidget);

      expect(
        find.byKey(const Key('social-interaction-date-filter-card')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ocultar filtro'), findsOneWidget);

      expect(
        find.byKey(const Key('social-interaction-date-filter-card')),
        findsOneWidget,
      );

      expect(find.text('Periodo'), findsOneWidget);

      expect(find.text('Desde'), findsOneWidget);

      expect(find.text('Hasta'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(
        find.byKey(const Key('social-interaction-date-filter-card')),
        findsNothing,
      );
    });

    testWidgets('Quitar filtro limpia fechas y elimina Filtro activo', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final context = tester.element(
        find.byKey(const Key('social-interaction-date-filter-card')),
      );

      final viewModel = Provider.of<SocialInteractionManagementViewModel>(
        context,
        listen: false,
      );

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      await tester.pump();

      expect(find.text('20 sep 2026'), findsOneWidget);

      expect(viewModel.applyDateFilter(), isTrue);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filtro activo'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('social-interaction-clear-date-filter')),
      );

      await tester.pump();

      expect(viewModel.hasAppliedDateFilter, isFalse);

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);
    });

    testWidgets('Nuevo registro utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(
        find.byKey(const Key('social-interaction-new-record-button')),
      );

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.socialInteractionNew);

      await tester.tap(find.byKey(const Key('close-social-interaction-new')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.socialInteraction);

      expect(repository.recoveryCount, 2);
    });

    testWidgets('el menú ofrece editar y eliminar', (tester) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      final menu = find.byKey(
        const Key('social-interaction-menu-interaccion-1'),
      );

      await _scrollUntilVisible(tester, menu);

      await tester.tap(menu);

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('abrir un registro utiliza la ruta canónica de Eventos', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      final record = find.byKey(
        const Key('social-interaction-open-interaccion-1'),
      );

      await _scrollUntilVisible(tester, record);

      await tester.tap(record);

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.socialInteractionDetail);

      expect(
        find.byKey(const Key('test-social-interaction-detail')),
        findsOneWidget,
      );
    });

    testWidgets('editar utiliza la ruta canónica de Eventos', (tester) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      final menu = find.byKey(
        const Key('social-interaction-menu-interaccion-1'),
      );

      await _scrollUntilVisible(tester, menu);

      await tester.tap(menu);

      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.socialInteractionEdit);

      expect(
        find.byKey(const Key('test-social-interaction-edit')),
        findsOneWidget,
      );
    });

    testWidgets('confirma eliminación definitiva y retira el evento', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      final menu = find.byKey(
        const Key('social-interaction-menu-interaccion-1'),
      );

      await _scrollUntilVisible(tester, menu);

      await tester.tap(menu);

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar evento?'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('confirm-delete-social-interaction')),
      );

      await tester.pumpAndSettle();

      expect(repository.deletedRecordId, 'interaccion-1');

      expect(repository.deletedAnonymousId, 'seguimiento-actual');

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-1')),
        findsNothing,
      );

      expect(find.text('Evento eliminado correctamente.'), findsOneWidget);
    });

    testWidgets('muestra estado vacío cuando no existen registros', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository();

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('social-interaction-empty-state')),
        findsOneWidget,
      );

      expect(
        find.text('Aún no hay registros de interacción social'),
        findsOneWidget,
      );

      expect(
        find.text(
          'Los nuevos registros de interacción social aparecerán aquí.',
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeSocialInteractionManagementRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SocialInteractionManagementView(
        repository: repository,
        anonymousId: 'seguimiento-actual',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

GoRouter _createRouter(_FakeSocialInteractionManagementRepository repository) {
  return GoRouter(
    initialLocation: AppRoutes.socialInteraction,
    routes: [
      GoRoute(
        path: AppRoutes.socialInteraction,
        builder: (context, state) {
          return SocialInteractionManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.socialInteractionNew,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-social-interaction-new'),
            body: Center(
              child: FilledButton(
                key: const Key('close-social-interaction-new'),
                onPressed: () {
                  context.pop();
                },
                child: const Text('Cerrar nuevo registro'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.socialInteractionDetail,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-social-interaction-detail'),
            body: Center(child: Text('Detalle de interacción social')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.socialInteractionEdit,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-social-interaction-edit'),
            body: Center(child: Text('Edición de interacción social')),
          );
        },
      ),
    ],
  );
}

SocialInteractionRecord _record() {
  return SocialInteractionRecord(
    recordId: 'interaccion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: SocialInteractionCategory.socialExchange,
    context: 'Actividad recreativa',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeSocialInteractionManagementRepository
    implements SocialInteractionManagementRepository {
  List<SocialInteractionRecord> records = [];

  int recoveryCount = 0;

  String? deletedAnonymousId;

  String? deletedRecordId;

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    recoveryCount += 1;

    return List.unmodifiable(records);
  }

  @override
  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  }) async {
    deletedAnonymousId = anonymousId;

    deletedRecordId = recordId;

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {}

  @override
  Future<void> updateSocialInteraction(SocialInteractionRecord record) async {}
}
