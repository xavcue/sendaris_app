import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_management_repository.dart';
import 'package:sendaris/features/atypical_situation/presentation/viewmodels/atypical_situation_management_view_model.dart';
import 'package:sendaris/features/atypical_situation/presentation/views/atypical_situation_management_view.dart';

void main() {
  group('AtypicalSituationManagementView', () {
    testWidgets('muestra la gestión con nuevo registro y datos del evento', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      expect(
        find.text('Gestión de registros de otra situación'),
        findsOneWidget,
      );

      expect(find.text('Nuevo registro'), findsOneWidget);

      expect(find.text('Evento inesperado'), findsOneWidget);

      expect(find.text('22 sep 2026'), findsOneWidget);

      expect(
        find.text('Descripción: Se suspendió una actividad programada.'),
        findsOneWidget,
      );

      expect(find.text('situacion-1'), findsNothing);

      expect(find.text('seguimiento-actual'), findsNothing);
    });

    testWidgets('el filtro inicia contraído y muestra únicamente Filtrar', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('atypical-situation-filter-toggle')),
        findsOneWidget,
      );

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

      expect(
        find.byKey(const Key('atypical-situation-date-filter-card')),
        findsNothing,
      );

      expect(find.text('Periodo'), findsNothing);
    });

    testWidgets('permite expandir y contraer el filtro', (tester) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('atypical-situation-filter-toggle')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ocultar filtro'), findsOneWidget);

      expect(
        find.byKey(const Key('atypical-situation-date-filter-card')),
        findsOneWidget,
      );

      expect(find.text('Periodo'), findsOneWidget);

      expect(
        find.text(
          'Filtra los registros de otra situación '
          'por la fecha registrada.',
        ),
        findsOneWidget,
      );

      expect(find.text('Desde'), findsOneWidget);

      expect(find.text('Hasta'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));

      expect(find.text('Aplicar'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('atypical-situation-filter-toggle')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(
        find.byKey(const Key('atypical-situation-date-filter-card')),
        findsNothing,
      );
    });

    testWidgets(
      'con filtro aplicado muestra contador parcial y Filtro activo',
      (tester) async {
        final repository = _FakeAtypicalSituationManagementRepository()
          ..records = [
            _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
            _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
          ];

        await _pumpView(tester, repository);

        await tester.tap(
          find.byKey(const Key('atypical-situation-filter-toggle')),
        );

        await tester.pumpAndSettle();

        final viewModel = _viewModelFromTester(tester);

        viewModel.setPendingStartDate(DateTime(2026, 9, 22));

        expect(viewModel.applyDateFilter(), isTrue);

        await tester.pump();

        expect(find.text('1 de 2'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('atypical-situation-filter-toggle')),
        );

        await tester.pumpAndSettle();

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(
          find.byKey(const Key('atypical-situation-date-filter-card')),
          findsNothing,
        );

        expect(viewModel.hasAppliedDateFilter, isTrue);
      },
    );

    testWidgets('Quitar filtro limpia pendientes y aplicados', (tester) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
          _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
        ];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('atypical-situation-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final viewModel = _viewModelFromTester(tester);

      viewModel.setPendingStartDate(DateTime(2026, 9, 22));

      viewModel.applyDateFilter();

      await tester.pump();

      expect(find.text('1 de 2'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('atypical-situation-clear-date-filter')),
      );

      await tester.pump();

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);

      expect(viewModel.appliedStartDate, isNull);

      expect(viewModel.appliedEndDate, isNull);

      expect(find.text('1 de 2'), findsNothing);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));
    });

    testWidgets('muestra estado vacío cuando no existen registros', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository();

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('atypical-situation-empty-state')),
        findsOneWidget,
      );

      expect(
        find.text('Aún no hay registros de otra situación'),
        findsOneWidget,
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('muestra estado sin resultados cuando el filtro no coincide', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'situacion-1', date: DateTime(2026, 9, 22)),
        ];

      await _pumpView(tester, repository);

      final viewModel = _viewModelFromTester(tester);

      viewModel.setPendingStartDate(DateTime(2026, 10, 1));

      viewModel.applyDateFilter();

      await tester.pump();

      expect(
        find.byKey(const Key('atypical-situation-no-filter-results')),
        findsOneWidget,
      );

      expect(find.text('No hay registros en este periodo'), findsOneWidget);

      expect(find.text('0 de 1'), findsOneWidget);
    });

    testWidgets('el menú ofrece editar y eliminar', (tester) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('atypical-situation-menu-situacion-1')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('elimina después de confirmar y muestra éxito', (tester) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'situacion-1'),
          _record(recordId: 'situacion-2'),
        ];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('atypical-situation-menu-situacion-1')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar evento?'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('confirm-delete-atypical-situation')),
      );

      await tester.pumpAndSettle();

      expect(repository.deletedAnonymousId, 'seguimiento-actual');

      expect(repository.deletedRecordId, 'situacion-1');

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-1')),
        findsNothing,
      );

      expect(find.text('Evento eliminado correctamente.'), findsOneWidget);
    });

    testWidgets('cancelar eliminación conserva el registro', (tester) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('atypical-situation-menu-situacion-1')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('cancel-delete-atypical-situation')),
      );

      await tester.pumpAndSettle();

      expect(repository.deletedRecordId, isNull);

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-1')),
        findsOneWidget,
      );
    });

    testWidgets('nuevo registro abre la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      final initialRecoveryCalls = repository.recoveryCalls;

      await tester.tap(
        find.byKey(const Key('atypical-situation-new-record-button')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Destino nuevo registro'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('return-from-new-atypical-situation')),
      );

      await tester.pumpAndSettle();

      expect(repository.recoveryCalls, greaterThan(initialRecoveryCalls));
    });

    testWidgets('tocar una tarjeta abre la ruta canónica de detalle', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('atypical-situation-open-situacion-1')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Destino detalle'), findsOneWidget);

      expect(find.text('Registro: situacion-1'), findsOneWidget);
    });

    testWidgets('editar abre la ruta canónica y recarga cuando regresa true', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'situacion-1')];

      await _pumpView(tester, repository);

      final initialRecoveryCalls = repository.recoveryCalls;

      await tester.tap(
        find.byKey(const Key('atypical-situation-menu-situacion-1')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(find.text('Destino editar'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('return-edit-atypical-situation-true')),
      );

      await tester.pumpAndSettle();

      expect(repository.recoveryCalls, greaterThan(initialRecoveryCalls));
    });
  });
}

AtypicalSituationManagementViewModel _viewModelFromTester(WidgetTester tester) {
  final context = tester.element(
    find.byKey(const Key('atypical-situation-management-view')),
  );

  return Provider.of<AtypicalSituationManagementViewModel>(
    context,
    listen: false,
  );
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeAtypicalSituationManagementRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1100, 1900));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/events/atypical-situation',
    routes: [
      GoRoute(
        path: '/events/atypical-situation',
        builder: (context, state) {
          return AtypicalSituationManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: '/events/atypical-situation/new',
        builder: (context, state) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Destino nuevo registro'),
                  FilledButton(
                    key: const Key('return-from-new-atypical-situation'),
                    onPressed: () {
                      context.pop();
                    },
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/events/atypical-situation/detail',
        builder: (context, state) {
          final record = state.extra! as AtypicalSituationRecord;

          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Destino detalle'),
                  Text('Registro: ${record.recordId}'),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/events/atypical-situation/edit',
        builder: (context, state) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Destino editar'),
                  FilledButton(
                    key: const Key('return-edit-atypical-situation-true'),
                    onPressed: () {
                      context.pop(true);
                    },
                    child: const Text('Guardar simulación'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));

  await tester.pumpAndSettle();
}

AtypicalSituationRecord _record({
  required String recordId,
  DateTime? date,
  AtypicalSituationCategory category =
      AtypicalSituationCategory.unexpectedEvent,
  String observation = 'Se suspendió una actividad programada.',
}) {
  return AtypicalSituationRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date ?? DateTime(2026, 9, 22),
    category: category,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeAtypicalSituationManagementRepository
    implements AtypicalSituationManagementRepository {
  List<AtypicalSituationRecord> records = [];

  int recoveryCalls = 0;

  String? deletedAnonymousId;
  String? deletedRecordId;

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    recoveryCalls++;

    return List<AtypicalSituationRecord>.from(records);
  }

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {
    deletedAnonymousId = anonymousId;
    deletedRecordId = recordId;

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {}
}
