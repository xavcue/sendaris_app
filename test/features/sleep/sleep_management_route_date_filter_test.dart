import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_management_repository.dart';
import 'package:sendaris/features/sleep/presentation/views/sleep_management_view.dart';

void main() {
  group('SleepManagementView - filtro inicial desde ruta', () {
    testWidgets('date filtra automáticamente el listado al día solicitado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeSleepManagementRepository()
        ..records = [
          _record(recordId: 'sueno-hoy-1', date: DateTime(2026, 10, 12)),
          _record(recordId: 'sueno-hoy-2', date: DateTime(2026, 10, 12)),
          _record(recordId: 'sueno-anterior', date: DateTime(2026, 10, 11)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.sleep}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.sleep);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('sleep-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('sleep-record-sueno-hoy-1')), findsOneWidget);

      expect(find.byKey(const Key('sleep-record-sueno-hoy-2')), findsOneWidget);

      expect(
        find.byKey(const Key('sleep-record-sueno-anterior')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(const Key('sleep-start-date-button'));

      final endDateButton = find.byKey(const Key('sleep-end-date-button'));

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

      expect(find.byKey(const Key('sleep-clear-date-filter')), findsOneWidget);
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

      final repository = _FakeSleepManagementRepository()
        ..records = [
          _record(recordId: 'sueno-hoy', date: DateTime(2026, 10, 12)),
          _record(recordId: 'sueno-anterior', date: DateTime(2026, 10, 11)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: AppRoutes.sleep,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(find.byKey(const Key('sleep-record-sueno-hoy')), findsOneWidget);

      expect(
        find.byKey(const Key('sleep-record-sueno-anterior')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(const Key('sleep-start-date-button'));

      final endDateButton = find.byKey(const Key('sleep-end-date-button'));

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

      final repository = _FakeSleepManagementRepository()
        ..records = [
          _record(recordId: 'sueno-1', date: DateTime(2026, 10, 12)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.sleep}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(find.byKey(const Key('sleep-record-sueno-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sleep-filter-toggle-button')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(const Key('sleep-start-date-button'));

      final endDateButton = find.byKey(const Key('sleep-end-date-button'));

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
  _FakeSleepManagementRepository repository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
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
    ],
  );
}

SleepRecord _record({required String recordId, required DateTime date}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return SleepRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    startTime: '10:00',
    endTime: '11:00',
    durationMinutes: 60,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeSleepManagementRepository implements SleepManagementRepository {
  List<SleepRecord> records = [];

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return List<SleepRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveSleep(SleepRecord record) async {}

  @override
  Future<void> updateSleep(SleepRecord record) async {}

  @override
  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}
