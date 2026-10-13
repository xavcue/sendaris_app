import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_management_repository.dart';
import 'package:sendaris/features/feeding/presentation/views/feeding_management_view.dart';

void main() {
  group('FeedingManagementView - filtro inicial desde ruta', () {
    testWidgets('date filtra automáticamente el listado al día solicitado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'alimentacion-hoy-1', date: DateTime(2026, 10, 12)),
          _record(recordId: 'alimentacion-hoy-2', date: DateTime(2026, 10, 12)),
          _record(
            recordId: 'alimentacion-anterior',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.feeding}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.feeding);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('feeding-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('feeding-record-alimentacion-hoy-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('feeding-record-alimentacion-hoy-2')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('feeding-record-alimentacion-anterior')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('feeding-start-date-button'),
      );

      final endDateButton = find.byKey(const Key('feeding-end-date-button'));

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
        find.byKey(const Key('feeding-clear-date-filter')),
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

      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'alimentacion-hoy', date: DateTime(2026, 10, 12)),
          _record(
            recordId: 'alimentacion-anterior',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final router = _createRouter(
        repository,
        initialLocation: AppRoutes.feeding,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('feeding-record-alimentacion-hoy')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('feeding-record-alimentacion-anterior')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('feeding-start-date-button'),
      );

      final endDateButton = find.byKey(const Key('feeding-end-date-button'));

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

      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'alimentacion-1', date: DateTime(2026, 10, 12)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.feeding}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('feeding-record-alimentacion-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('feeding-filter-toggle')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('feeding-start-date-button'),
      );

      final endDateButton = find.byKey(const Key('feeding-end-date-button'));

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
  _FakeFeedingManagementRepository repository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
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
    ],
  );
}

FeedingRecord _record({required String recordId, required DateTime date}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return FeedingRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    category: FeedingCategory.lunch,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeFeedingManagementRepository implements FeedingManagementRepository {
  List<FeedingRecord> records = [];

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return List<FeedingRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveFeeding(FeedingRecord record) async {}

  @override
  Future<void> updateFeeding(FeedingRecord record) async {}

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}
