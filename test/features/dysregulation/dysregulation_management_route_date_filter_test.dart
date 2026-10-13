import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_management_repository.dart';
import 'package:sendaris/features/dysregulation/presentation/views/dysregulation_management_view.dart';

void main() {
  group('DysregulationManagementView - filtro inicial desde ruta', () {
    testWidgets('date filtra automáticamente el listado al día solicitado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(
            recordId: 'desregulacion-hoy-1',
            date: DateTime(2026, 10, 12),
          ),
          _record(
            recordId: 'desregulacion-hoy-2',
            date: DateTime(2026, 10, 12),
          ),
          _record(
            recordId: 'desregulacion-anterior',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.dysregulation}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.dysregulation);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('dysregulation-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-hoy-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-hoy-2')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-anterior')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('dysregulation-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('dysregulation-end-date-button'),
      );

      expect(startDateButton, findsOneWidget);

      expect(endDateButton, findsOneWidget);

      expect(
        find.descendant(
          of: startDateButton,
          matching: find.text('12 oct 2026'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(of: endDateButton, matching: find.text('12 oct 2026')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('dysregulation-clear-date-filter')),
        findsOneWidget,
      );
    });

    testWidgets('sin date conserva el listado normal sin filtro automático', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'desregulacion-hoy', date: DateTime(2026, 10, 12)),
          _record(
            recordId: 'desregulacion-anterior',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final router = _createRouter(
        repository,
        initialLocation: AppRoutes.dysregulation,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-hoy')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-anterior')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('dysregulation-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('dysregulation-end-date-button'),
      );

      expect(
        find.descendant(
          of: startDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: endDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('date inválida se ignora de forma segura', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'desregulacion-1', date: DateTime(2026, 10, 12)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.dysregulation}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('dysregulation-record-desregulacion-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dysregulation-filter-toggle')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('dysregulation-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('dysregulation-end-date-button'),
      );

      expect(
        find.descendant(
          of: startDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: endDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );
    });
  });
}

GoRouter _createRouter(
  _FakeDysregulationManagementRepository repository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.dysregulation,
        builder: (context, state) {
          return DysregulationManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
    ],
  );
}

DysregulationRecord _record({
  required String recordId,
  required DateTime date,
}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return DysregulationRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeDysregulationManagementRepository
    implements DysregulationManagementRepository {
  List<DysregulationRecord> records = [];

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    return List<DysregulationRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {}

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {}

  @override
  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}
