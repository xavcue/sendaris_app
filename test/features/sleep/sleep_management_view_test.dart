import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/sleep/domain/exceptions/sleep_failure.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_management_repository.dart';
import 'package:sendaris/features/sleep/presentation/viewmodels/sleep_management_view_model.dart';
import 'package:sendaris/features/sleep/presentation/views/sleep_management_view.dart';

void main() {
  group('SleepManagementView', () {
    testWidgets('muestra los registros de sueño con la acción Nuevo registro', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [
          _record(recordId: 'sueno-1', observation: 'Descanso continuo.'),
        ],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Gestión de registros de sueño'), findsOneWidget);

      expect(
        find.text('Consulta y administra los registros de sueño.'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('sleep-new-button')), findsOneWidget);

      expect(find.text('Nuevo registro'), findsOneWidget);

      expect(find.byKey(const Key('sleep-date-filter-card')), findsNothing);

      expect(find.byKey(const Key('sleep-record-sueno-1')), findsOneWidget);

      expect(find.text('22:00 – 06:00'), findsOneWidget);

      expect(find.text('22 sep 2026 – 23 sep 2026'), findsOneWidget);

      expect(find.text('8 h'), findsOneWidget);

      expect(find.text('Descanso continuo.'), findsOneWidget);

      expect(find.textContaining('sueno-1'), findsNothing);

      expect(find.textContaining('seguimiento-actual'), findsNothing);
    });

    testWidgets('el filtro inicia contraído y puede expandirse y contraerse', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-1')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.byKey(const Key('sleep-date-filter-card')), findsNothing);

      expect(find.text('Periodo'), findsNothing);

      await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sleep-date-filter-card')), findsOneWidget);

      expect(find.text('Periodo'), findsOneWidget);

      expect(
        find.text(
          'Filtra los registros por la fecha en que inició el periodo de sueño.',
        ),
        findsOneWidget,
      );

      expect(find.text('Desde'), findsOneWidget);

      expect(find.text('Hasta'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));

      expect(find.text('Aplicar'), findsOneWidget);

      expect(find.text('Ocultar filtro'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sleep-date-filter-card')), findsNothing);

      expect(find.text('Filtrar'), findsOneWidget);
    });

    testWidgets(
      'el filtro aplicado se conserva al contraer y muestra Filtro activo',
      (tester) async {
        final repository = _FakeSleepManagementRepository(
          records: [
            _record(recordId: 'sueno-22', date: DateTime(2026, 9, 22)),
            _record(recordId: 'sueno-26', date: DateTime(2026, 9, 26)),
          ],
        );

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

        await tester.pumpAndSettle();

        final filterContext = tester.element(
          find.byKey(const Key('sleep-date-filter-card')),
        );

        final viewModel = Provider.of<SleepManagementViewModel>(
          filterContext,
          listen: false,
        );

        viewModel
          ..setPendingStartDate(DateTime(2026, 9, 26))
          ..setPendingEndDate(DateTime(2026, 9, 26));

        expect(viewModel.applyDateFilter(), isTrue);

        await tester.pump();

        expect(viewModel.recordCount, 1);

        expect(viewModel.hasAppliedDateFilter, isTrue);

        await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sleep-date-filter-card')), findsNothing);

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(find.byKey(const Key('sleep-record-sueno-26')), findsOneWidget);

        expect(find.byKey(const Key('sleep-record-sueno-22')), findsNothing);
      },
    );

    testWidgets('Quitar filtro limpia fechas pendientes y aplicadas', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-1')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

      await tester.pumpAndSettle();

      final filterContext = tester.element(
        find.byKey(const Key('sleep-date-filter-card')),
      );

      final viewModel = Provider.of<SleepManagementViewModel>(
        filterContext,
        listen: false,
      );

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      await tester.pump();

      expect(find.byKey(const Key('sleep-clear-date-filter')), findsOneWidget);

      expect(find.text('20 sep 2026'), findsOneWidget);

      expect(viewModel.applyDateFilter(), isTrue);

      await tester.pump();

      await tester.tap(find.byKey(const Key('sleep-clear-date-filter')));

      await tester.pump();

      expect(viewModel.hasPendingDateFilter, isFalse);

      expect(viewModel.hasAppliedDateFilter, isFalse);

      expect(find.byKey(const Key('sleep-clear-date-filter')), findsNothing);

      expect(find.text('Sin seleccionar'), findsNWidgets(2));
    });

    testWidgets(
      'muestra una sola fecha cuando el sueño inicia y termina el mismo día',
      (tester) async {
        final repository = _FakeSleepManagementRepository(
          records: [
            _record(
              recordId: 'sueno-diurno',
              date: DateTime(2026, 9, 22),
              startTime: '14:00',
              endTime: '16:30',
              durationMinutes: 150,
            ),
          ],
        );

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        expect(find.text('14:00 – 16:30'), findsOneWidget);

        expect(find.text('22 sep 2026'), findsOneWidget);

        expect(find.text('22 sep 2026 – 23 sep 2026'), findsNothing);

        expect(find.text('2 h 30 min'), findsOneWidget);
      },
    );

    testWidgets('Nuevo registro utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-1')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('sleep-new-button')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.sleepNew);

      expect(find.byKey(const Key('test-sleep-new')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-sleep-new')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.sleep);

      expect(repository.recoveryCount, 2);
    });

    testWidgets('tocar un registro utiliza la ruta canónica de detalle', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-1')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sleep-open-sueno-1')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.sleepDetail);

      expect(find.byKey(const Key('test-sleep-detail')), findsOneWidget);
    });

    testWidgets('muestra Editar y Eliminar desde el menú del registro', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-menu')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sleep-menu-sueno-menu')));

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('Editar utiliza la ruta canónica y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-editar')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);

      await tester.tap(find.byKey(const Key('sleep-menu-sueno-editar')));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.sleepEdit);

      expect(find.byKey(const Key('test-sleep-edit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-sleep-edit')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.sleep);

      expect(repository.recoveryCount, 2);
    });

    testWidgets(
      'el filtro aplicado sin coincidencias muestra un estado específico',
      (tester) async {
        final repository = _FakeSleepManagementRepository(
          records: [
            _record(recordId: 'sueno-septiembre', date: DateTime(2026, 9, 10)),
          ],
        );

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        final context = tester.element(
          find.byKey(const Key('sleep-management-list')),
        );

        final viewModel = Provider.of<SleepManagementViewModel>(
          context,
          listen: false,
        );

        viewModel
          ..setPendingStartDate(DateTime(2026, 9, 20))
          ..setPendingEndDate(DateTime(2026, 9, 25));

        expect(viewModel.applyDateFilter(), isTrue);

        await tester.pump();

        expect(
          find.byKey(const Key('sleep-no-filter-results')),
          findsOneWidget,
        );

        expect(find.text('No hay registros en este periodo'), findsOneWidget);

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(
          find.byKey(const Key('sleep-clear-empty-filter')),
          findsOneWidget,
        );
      },
    );

    testWidgets('eliminar pide confirmación y retira el registro', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository(
        records: [_record(recordId: 'sueno-eliminar')],
      );

      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sleep-menu-sueno-eliminar')));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar'));

      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar evento?'), findsOneWidget);

      expect(
        find.text(
          'Este registro se eliminará definitivamente '
          'y dejará de formar parte de los indicadores '
          'calculados con estos datos. Esta acción no '
          'se puede deshacer.',
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('cancel-delete-sleep')), findsOneWidget);

      expect(find.byKey(const Key('confirm-delete-sleep')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-delete-sleep')));

      await tester.pump();

      expect(repository.deletedRecords, [
        (anonymousId: 'seguimiento-actual', recordId: 'sueno-eliminar'),
      ]);

      expect(
        find.byKey(const Key('sleep-record-sueno-eliminar')),
        findsNothing,
      );

      expect(find.text('Evento eliminado correctamente.'), findsOneWidget);
    });

    testWidgets(
      'un error inicial muestra reintento y conserva lenguaje de usuario',
      (tester) async {
        final repository = _FakeSleepManagementRepository(
          recoveryFailure: const SleepFailure(
            'No fue posible cargar los registros de sueño.',
          ),
        );

        final router = _createRouter(repository);

        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sleep-management-error')), findsOneWidget);

        expect(
          find.text('No fue posible cargar los registros de sueño.'),
          findsOneWidget,
        );

        expect(find.byKey(const Key('sleep-retry-button')), findsOneWidget);

        expect(find.textContaining('UUID'), findsNothing);

        expect(find.textContaining('perfil activo'), findsNothing);
      },
    );
  });
}

GoRouter _createRouter(_FakeSleepManagementRepository repository) {
  return GoRouter(
    initialLocation: AppRoutes.sleep,
    routes: [
      GoRoute(
        path: AppRoutes.sleep,
        builder: (context, state) {
          return SleepManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sleepNew,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-sleep-new'),
            body: Center(
              child: FilledButton(
                key: const Key('close-sleep-new'),
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
        path: AppRoutes.sleepDetail,
        builder: (context, state) {
          return const Scaffold(
            key: Key('test-sleep-detail'),
            body: Center(child: Text('Detalle de sueño')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sleepEdit,
        builder: (context, state) {
          return Scaffold(
            key: const Key('test-sleep-edit'),
            body: Center(
              child: FilledButton(
                key: const Key('close-sleep-edit'),
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

SleepRecord _record({
  required String recordId,
  DateTime? date,
  String startTime = '22:00',
  String endTime = '06:00',
  int durationMinutes = 480,
  String? observation,
}) {
  return SleepRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date ?? DateTime(2026, 9, 22),
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 23, 8),
    updatedAt: DateTime.utc(2026, 9, 23, 8),
  );
}

class _FakeSleepManagementRepository implements SleepManagementRepository {
  _FakeSleepManagementRepository({
    List<SleepRecord> records = const [],
    this.recoveryFailure,
  }) : _records = List<SleepRecord>.from(records);

  final List<SleepRecord> _records;

  SleepFailure? recoveryFailure;

  int recoveryCount = 0;

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  @override
  Future<void> saveSleep(SleepRecord record) async {}

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    recoveryCount += 1;

    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List.unmodifiable(_records);
  }

  @override
  Future<void> updateSleep(SleepRecord record) async {}

  @override
  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  }) async {
    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));

    _records.removeWhere((record) => record.recordId == recordId);
  }
}
