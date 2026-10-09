import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_management_repository.dart';
import 'package:sendaris/features/feeding/presentation/viewmodels/feeding_management_view_model.dart';
import 'package:sendaris/features/feeding/presentation/views/feeding_management_view.dart';

void main() {
  group('FeedingManagementView', () {
    testWidgets(
      'muestra administración de alimentación con Nuevo registro y contador coloreado',
      (tester) async {
        final repository = _FakeFeedingManagementRepository()
          ..records = [_record()];

        await _pumpView(tester, repository);

        expect(
          find.text('Gestión de registros de alimentación'),
          findsOneWidget,
        );

        expect(find.text('Almuerzo'), findsOneWidget);

        expect(find.text('22 sep 2026'), findsOneWidget);

        expect(find.text('Observación: Registro ficticio.'), findsOneWidget);

        expect(
          find.byKey(const Key('feeding-new-record-button')),
          findsOneWidget,
        );

        expect(find.text('Nuevo registro'), findsOneWidget);

        final countFinder = find.byKey(const Key('feeding-record-count'));

        expect(countFinder, findsOneWidget);

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

    testWidgets('el filtro inicia contraído y puede expandirse y contraerse', (
      tester,
    ) async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      expect(find.byKey(const Key('feeding-filter-toggle')), findsOneWidget);

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

      expect(find.byKey(const Key('feeding-date-filter-card')), findsNothing);

      await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

      await tester.pumpAndSettle();

      expect(find.text('Ocultar filtro'), findsOneWidget);

      expect(find.byKey(const Key('feeding-date-filter-card')), findsOneWidget);

      expect(find.text('Periodo'), findsOneWidget);

      expect(find.text('Desde'), findsOneWidget);

      expect(find.text('Hasta'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));

      expect(find.text('Aplicar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.byKey(const Key('feeding-date-filter-card')), findsNothing);
    });

    testWidgets(
      'Quitar filtro limpia las fechas y al contraer deja de mostrar filtro activo',
      (tester) async {
        final repository = _FakeFeedingManagementRepository()
          ..records = [_record()];

        await _pumpView(tester, repository);

        await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

        await tester.pumpAndSettle();

        final context = tester.element(
          find.byKey(const Key('feeding-date-filter-card')),
        );

        final viewModel = Provider.of<FeedingManagementViewModel>(
          context,
          listen: false,
        );

        viewModel.setPendingStartDate(DateTime(2026, 9, 20));

        await tester.pump();

        expect(
          find.byKey(const Key('feeding-clear-date-filter')),
          findsOneWidget,
        );

        expect(find.text('Quitar filtro'), findsOneWidget);

        expect(find.text('20 sep 2026'), findsOneWidget);

        expect(viewModel.applyDateFilter(), isTrue);

        await tester.pump();

        expect(viewModel.hasAppliedDateFilter, isTrue);

        await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

        await tester.pumpAndSettle();

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(find.byKey(const Key('feeding-date-filter-card')), findsNothing);

        await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('feeding-clear-date-filter')));

        await tester.pump();

        expect(viewModel.hasPendingDateFilter, isFalse);

        expect(viewModel.hasAppliedDateFilter, isFalse);

        await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

        await tester.pumpAndSettle();

        expect(find.text('Filtrar'), findsOneWidget);

        expect(find.text('Filtro activo'), findsNothing);
      },
    );

    testWidgets('Nuevo registro utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [_record()];

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('feeding-new-record-button')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.feedingNew);

      expect(find.byKey(const Key('test-feeding-new')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-feeding-new')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.feeding);

      expect(repository.recoveryCount, 2);
    });

    testWidgets('el menú ofrece editar y eliminar', (tester) async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      final menu = find.byKey(const Key('feeding-menu-alimentacion-1'));

      await _scrollUntilVisible(tester, menu);

      await tester.tap(menu);

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets(
      'abrir un registro de alimentación utiliza la ruta canónica de Eventos',
      (tester) async {
        final repository = _FakeFeedingManagementRepository()
          ..records = [_record()];

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        final record = find.byKey(const Key('feeding-open-alimentacion-1'));

        await _scrollUntilVisible(tester, record);

        await tester.tap(record);

        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.feedingDetail);

        expect(find.byKey(const Key('test-feeding-detail')), findsOneWidget);
      },
    );

    testWidgets(
      'editar un registro de alimentación utiliza la ruta canónica de Eventos',
      (tester) async {
        final repository = _FakeFeedingManagementRepository()
          ..records = [_record()];

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        final menu = find.byKey(const Key('feeding-menu-alimentacion-1'));

        await _scrollUntilVisible(tester, menu);

        await tester.tap(menu);

        await tester.pumpAndSettle();

        await tester.tap(find.text('Editar'));

        await tester.pumpAndSettle();

        expect(router.state.uri.path, AppRoutes.feedingEdit);

        expect(find.byKey(const Key('test-feeding-edit')), findsOneWidget);
      },
    );

    testWidgets('confirma la eliminación definitiva y retira el evento', (
      tester,
    ) async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [_record()];

      await _pumpView(tester, repository);

      final menu = find.byKey(const Key('feeding-menu-alimentacion-1'));

      await _scrollUntilVisible(tester, menu);

      await tester.tap(menu);

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar evento?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-delete-feeding')));

      await tester.pumpAndSettle();

      expect(repository.deletedRecordId, 'alimentacion-1');

      expect(repository.deletedAnonymousId, 'seguimiento-actual');

      expect(
        find.byKey(const Key('feeding-record-alimentacion-1')),
        findsNothing,
      );

      expect(find.text('Evento eliminado correctamente.'), findsOneWidget);
    });

    testWidgets(
      'muestra estado vacío cuando no existen registros de alimentación',
      (tester) async {
        final repository = _FakeFeedingManagementRepository();

        await _pumpView(tester, repository);

        expect(find.byKey(const Key('feeding-empty-state')), findsOneWidget);

        expect(
          find.text('Aún no hay registros de alimentación'),
          findsOneWidget,
        );

        expect(
          find.text('Los nuevos registros de alimentación aparecerán aquí.'),
          findsOneWidget,
        );

        expect(find.textContaining('Registrar'), findsNothing);
      },
    );
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeFeedingManagementRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FeedingManagementView(
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

GoRouter _createRouter(_FakeFeedingManagementRepository repository) {
  return GoRouter(
    initialLocation: AppRoutes.feeding,
    routes: [
      GoRoute(
        path: AppRoutes.feeding,
        builder: (context, state) {
          return FeedingManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.feedingNew,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-feeding-new'),
            body: Center(
              child: FilledButton(
                key: const Key('close-feeding-new'),
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
        path: AppRoutes.feedingDetail,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-feeding-detail'),
            body: Center(child: Text('Detalle de alimentación')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.feedingEdit,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-feeding-edit'),
            body: Center(child: Text('Edición de alimentación')),
          );
        },
      ),
    ],
  );
}

FeedingRecord _record() {
  return FeedingRecord(
    recordId: 'alimentacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: FeedingCategory.lunch,
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeFeedingManagementRepository implements FeedingManagementRepository {
  List<FeedingRecord> records = [];

  int recoveryCount = 0;

  String? deletedAnonymousId;
  String? deletedRecordId;

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    recoveryCount += 1;

    return List.unmodifiable(records);
  }

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {
    deletedAnonymousId = anonymousId;

    deletedRecordId = recordId;

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveFeeding(FeedingRecord record) async {}

  @override
  Future<void> updateFeeding(FeedingRecord record) async {}
}
