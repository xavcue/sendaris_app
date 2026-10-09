import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/presentation/viewmodels/behavior_management_view_model.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_management_view.dart';

void main() {
  group('BehaviorManagementView', () {
    testWidgets('muestra la gestión de conducta con creación y registros', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Gestión de registros de conducta'), findsOneWidget);

      expect(find.byKey(const Key('behavior-new-button')), findsOneWidget);

      expect(find.text('Nuevo registro'), findsOneWidget);

      expect(find.text('Conducta repetitiva'), findsOneWidget);

      expect(find.text('Duración: 10 min'), findsOneWidget);

      expect(find.text('Intensidad: Media'), findsOneWidget);

      expect(find.text('Contexto: Cambio de actividad'), findsOneWidget);
    });

    testWidgets(
      'el filtro inicia contraído y al abrirlo muestra fechas y Aplicar',
      (tester) async {
        final repository = _FakeBehaviorManagementRepository()
          ..records = [_record()];

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        expect(find.text('Filtrar'), findsOneWidget);

        expect(find.text('Periodo'), findsNothing);

        expect(
          find.byKey(const Key('behavior-date-filter-card')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('behavior-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        expect(find.text('Periodo'), findsOneWidget);

        expect(
          find.text('Filtra las conductas por la fecha registrada.'),
          findsOneWidget,
        );

        expect(find.text('Desde'), findsOneWidget);

        expect(find.text('Hasta'), findsOneWidget);

        expect(find.text('Sin seleccionar'), findsNWidgets(2));

        expect(find.text('Aplicar'), findsOneWidget);

        expect(find.text('Ocultar filtro'), findsOneWidget);

        expect(
          find.byKey(const Key('behavior-clear-date-filter')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Quitar filtro aparece al seleccionar una fecha y desaparece al limpiar',
      (tester) async {
        final repository = _FakeBehaviorManagementRepository()
          ..records = [_record()];

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('behavior-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        final context = tester.element(
          find.byKey(const Key('behavior-date-filter-card')),
        );

        final viewModel = Provider.of<BehaviorManagementViewModel>(
          context,
          listen: false,
        );

        viewModel.setPendingStartDate(DateTime(2026, 9, 20));

        await tester.pump();

        expect(
          find.byKey(const Key('behavior-clear-date-filter')),
          findsOneWidget,
        );

        expect(find.text('Quitar filtro'), findsOneWidget);

        expect(find.text('20 sep 2026'), findsOneWidget);

        expect(viewModel.applyDateFilter(), isTrue);

        await tester.pump();

        expect(viewModel.hasActiveDateFilter, isTrue);

        await tester.tap(find.byKey(const Key('behavior-clear-date-filter')));

        await tester.pump();

        expect(
          find.byKey(const Key('behavior-clear-date-filter')),
          findsNothing,
        );

        expect(find.text('Quitar filtro'), findsNothing);

        expect(find.text('Sin seleccionar'), findsNWidgets(2));

        expect(viewModel.hasPendingDateFilter, isFalse);

        expect(viewModel.hasActiveDateFilter, isFalse);
      },
    );

    testWidgets('tocar una conducta abre la ruta canónica de detalle', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('behavior-open-conducta-1')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behaviorDetail);

      expect(find.byKey(const Key('test-behavior-detail')), findsOneWidget);
    });

    testWidgets('Nuevo registro utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('behavior-new-button')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behaviorNew);

      expect(find.byKey(const Key('test-behavior-new')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-behavior-new')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behavior);

      expect(repository.recoveryCount, 2);
    });

    testWidgets('el menú ofrece editar y eliminar', (tester) async {
      final repository = _FakeBehaviorManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('behavior-menu-conducta-1')));

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('Editar utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('behavior-menu-conducta-1')));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behaviorEdit);

      expect(find.byKey(const Key('test-behavior-edit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-behavior-edit')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behavior);

      expect(repository.recoveryCount, 2);
    });

    testWidgets('confirma la eliminación definitiva y retira la conducta', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('behavior-menu-conducta-1')));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar conducta?'), findsOneWidget);

      expect(
        find.textContaining('Esta acción no se puede deshacer'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('confirm-delete-behavior')));

      await tester.pumpAndSettle();

      expect(repository.deletedRecordId, 'conducta-1');

      expect(repository.deletedAnonymousId, 'seguimiento-actual');

      expect(find.byKey(const Key('behavior-record-conducta-1')), findsNothing);

      expect(find.text('Conducta eliminada correctamente.'), findsOneWidget);
    });

    testWidgets('muestra estado vacío cuando no existen conductas', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository();

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('behavior-empty-state')), findsOneWidget);

      expect(find.text('Aún no hay conductas'), findsOneWidget);

      expect(
        find.text('Los nuevos registros de conducta aparecerán aquí.'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('behavior-new-button')), findsOneWidget);
    });
  });
}

GoRouter _createRouter(_FakeBehaviorManagementRepository repository) {
  return GoRouter(
    initialLocation: AppRoutes.behavior,
    routes: [
      GoRoute(
        path: AppRoutes.behavior,
        builder: (context, state) {
          return BehaviorManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.behaviorNew,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-behavior-new'),
            body: Center(
              child: FilledButton(
                key: const Key('close-behavior-new'),
                onPressed: () {
                  context.pop(true);
                },
                child: const Text('Cerrar nuevo registro'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.behaviorDetail,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-behavior-detail'),
            body: Center(child: Text('Detalle de conducta')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.behaviorEdit,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-behavior-edit'),
            body: Center(
              child: FilledButton(
                key: const Key('close-behavior-edit'),
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

BehaviorRecord _record() {
  return BehaviorRecord(
    recordId: 'conducta-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    time: '19:49',
    category: BehaviorCategory.repetitiveBehavior,
    durationMinutes: 10,
    intensity: BehaviorIntensity.medium,
    context: 'Cambio de actividad',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 23, 0, 49),
    updatedAt: DateTime.utc(2026, 9, 23, 0, 49),
  );
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  List<BehaviorRecord> records = [];

  int recoveryCount = 0;

  String? deletedAnonymousId;
  String? deletedRecordId;

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    recoveryCount += 1;

    return List.unmodifiable(records);
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    deletedAnonymousId = anonymousId;
    deletedRecordId = recordId;

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {}
}
