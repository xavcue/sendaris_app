import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_management_repository.dart';
import 'package:sendaris/features/dysregulation/presentation/viewmodels/dysregulation_management_view_model.dart';
import 'package:sendaris/features/dysregulation/presentation/views/dysregulation_management_view.dart';

void main() {
  group('DysregulationManagementView', () {
    testWidgets('muestra la gestión con nuevo registro y datos del episodio', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      expect(
        find.text('Gestión de registros de desregulación'),
        findsOneWidget,
      );

      expect(find.text('Nuevo registro'), findsOneWidget);

      expect(find.text('Episodio de desregulación'), findsOneWidget);

      expect(find.text('22 sep 2026 · 14:30'), findsOneWidget);

      expect(find.text('12 min'), findsOneWidget);

      expect(find.text('Media'), findsOneWidget);

      expect(find.text('Contexto: Actividad cotidiana'), findsOneWidget);

      expect(find.text('Observación: Registro ficticio.'), findsOneWidget);

      expect(find.text('desregulacion-1'), findsNothing);

      expect(find.text('seguimiento-actual'), findsNothing);
    });

    testWidgets(
      'el filtro inicia contraído y muestra únicamente el botón Filtrar',
      (tester) async {
        final repository = _FakeDysregulationManagementRepository()
          ..records = [_record(recordId: 'desregulacion-1')];

        await _pumpView(tester, repository);

        expect(
          find.byKey(const Key('dysregulation-filter-toggle')),
          findsOneWidget,
        );

        expect(find.text('Filtrar'), findsOneWidget);

        expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

        expect(
          find.byKey(const Key('dysregulation-date-filter-card')),
          findsNothing,
        );

        expect(find.text('Periodo'), findsNothing);

        expect(
          find.byKey(const Key('dysregulation-start-date-button')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('dysregulation-end-date-button')),
          findsNothing,
        );
      },
    );

    testWidgets('permite expandir y contraer el filtro', (tester) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

      await tester.pumpAndSettle();

      expect(find.text('Ocultar filtro'), findsOneWidget);

      expect(
        find.byKey(const Key('dysregulation-date-filter-card')),
        findsOneWidget,
      );

      expect(find.text('Periodo'), findsOneWidget);

      expect(
        find.text(
          'Filtra los registros de desregulación '
          'por la fecha registrada.',
        ),
        findsOneWidget,
      );

      expect(find.text('Desde'), findsOneWidget);

      expect(find.text('Hasta'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));

      expect(find.text('Aplicar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(
        find.byKey(const Key('dysregulation-date-filter-card')),
        findsNothing,
      );
    });

    testWidgets(
      'el filtro aplicado se conserva al contraer y muestra Filtro activo',
      (tester) async {
        final repository = _FakeDysregulationManagementRepository()
          ..records = [
            _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
            _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
          ];

        await _pumpView(tester, repository);

        await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

        await tester.pumpAndSettle();

        final viewModel = _viewModelFromTester(tester);

        viewModel.setPendingStartDate(DateTime(2026, 9, 22));

        expect(viewModel.applyDateFilter(), isTrue);

        await tester.pump();

        expect(find.text('1 de 2'), findsOneWidget);

        await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

        await tester.pumpAndSettle();

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(
          find.byKey(const Key('dysregulation-date-filter-card')),
          findsNothing,
        );

        expect(viewModel.hasAppliedDateFilter, isTrue);

        expect(find.text('1 de 2'), findsOneWidget);
      },
    );

    testWidgets('Quitar filtro limpia valores pendientes y aplicados', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
          _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
        ];

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

      await tester.pumpAndSettle();

      final viewModel = _viewModelFromTester(tester);

      viewModel.setPendingStartDate(DateTime(2026, 9, 22));

      viewModel.applyDateFilter();

      await tester.pump();

      expect(find.text('1 de 2'), findsOneWidget);

      expect(
        find.byKey(const Key('dysregulation-clear-date-filter')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('dysregulation-clear-date-filter')),
      );

      await tester.pump();

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);

      expect(viewModel.appliedStartDate, isNull);

      expect(viewModel.appliedEndDate, isNull);

      expect(find.text('2'), findsOneWidget);

      expect(find.text('1 de 2'), findsNothing);

      expect(
        find.byKey(const Key('dysregulation-clear-date-filter')),
        findsNothing,
      );

      expect(find.text('Sin seleccionar'), findsNWidgets(2));
    });

    testWidgets('muestra estado vacío cuando no existen registros', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository();

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('dysregulation-empty-state')),
        findsOneWidget,
      );

      expect(
        find.text('Aún no hay registros de desregulación'),
        findsOneWidget,
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('muestra estado sin resultados cuando el filtro no coincide', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'desregulacion-1', date: DateTime(2026, 9, 22)),
        ];

      await _pumpView(tester, repository);

      final viewModel = _viewModelFromTester(tester);

      viewModel.setPendingStartDate(DateTime(2026, 10, 1));

      viewModel.applyDateFilter();

      await tester.pump();

      expect(
        find.byKey(const Key('dysregulation-no-filter-results')),
        findsOneWidget,
      );

      expect(find.text('No hay registros en este periodo'), findsOneWidget);

      expect(find.text('0 de 1'), findsOneWidget);
    });

    testWidgets('el menú ofrece editar y eliminar', (tester) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('dysregulation-menu-desregulacion-1')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('elimina después de confirmar y muestra éxito', (tester) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'desregulacion-1'),
          _record(recordId: 'desregulacion-2'),
        ];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('dysregulation-menu-desregulacion-1')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar evento?'), findsOneWidget);

      expect(
        find.textContaining('Esta acción no se puede deshacer'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('confirm-delete-dysregulation')));

      await tester.pumpAndSettle();

      expect(repository.deletedRecords, [
        (anonymousId: 'seguimiento-actual', recordId: 'desregulacion-1'),
      ]);

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-1')),
        findsNothing,
      );

      expect(find.text('Evento eliminado correctamente.'), findsOneWidget);
    });

    testWidgets('cancelar eliminación conserva el registro', (tester) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('dysregulation-menu-desregulacion-1')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel-delete-dysregulation')));

      await tester.pumpAndSettle();

      expect(repository.deletedRecords, isEmpty);

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-1')),
        findsOneWidget,
      );
    });

    testWidgets('nuevo registro abre la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      final initialRecoveries = repository.recoveryCalls;

      await tester.tap(
        find.byKey(const Key('dysregulation-new-record-button')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Destino nuevo registro'), findsOneWidget);

      await tester.tap(find.byKey(const Key('return-from-new')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dysregulation-management-view')),
        findsOneWidget,
      );

      expect(repository.recoveryCalls, greaterThan(initialRecoveries));
    });

    testWidgets('tocar una tarjeta abre la ruta canónica de detalle', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('dysregulation-open-desregulacion-1')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Destino detalle'), findsOneWidget);

      expect(find.text('Registro: desregulacion-1'), findsOneWidget);
    });

    testWidgets('editar abre la ruta canónica y recarga cuando regresa true', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

      await _pumpView(tester, repository);

      final initialRecoveries = repository.recoveryCalls;

      await tester.tap(
        find.byKey(const Key('dysregulation-menu-desregulacion-1')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(find.text('Destino editar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('return-edit-true')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dysregulation-management-view')),
        findsOneWidget,
      );

      expect(repository.recoveryCalls, greaterThan(initialRecoveries));
    });
  });
}

DysregulationManagementViewModel _viewModelFromTester(WidgetTester tester) {
  final context = tester.element(
    find.byKey(const Key('dysregulation-management-view')),
  );

  return Provider.of<DysregulationManagementViewModel>(context, listen: false);
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeDysregulationManagementRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1100, 1900));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/events/dysregulation',
    routes: [
      GoRoute(
        path: '/events/dysregulation',
        builder: (context, state) {
          return DysregulationManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: '/events/dysregulation/new',
        builder: (context, state) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Destino nuevo registro'),
                  FilledButton(
                    key: const Key('return-from-new'),
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
        path: '/events/dysregulation/detail',
        builder: (context, state) {
          final record = state.extra! as DysregulationRecord;

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
        path: '/events/dysregulation/edit',
        builder: (context, state) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Destino editar'),
                  FilledButton(
                    key: const Key('return-edit-true'),
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

DysregulationRecord _record({
  required String recordId,
  DateTime? date,
  String? time = '14:30',
  int? durationMinutes = 12,
  DysregulationIntensity? intensity = DysregulationIntensity.medium,
  String? context = 'Actividad cotidiana',
  String? observation = 'Registro ficticio.',
}) {
  return DysregulationRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date ?? DateTime(2026, 9, 22),
    time: time,
    durationMinutes: durationMinutes,
    intensity: intensity,
    context: context,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeDysregulationManagementRepository
    implements DysregulationManagementRepository {
  List<DysregulationRecord> records = [];

  int recoveryCalls = 0;

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    recoveryCalls++;

    return List<DysregulationRecord>.from(records);
  }

  @override
  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  }) async {
    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {}

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {}
}
