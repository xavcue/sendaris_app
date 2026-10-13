import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_management_view.dart';

void main() {
  group('BehaviorManagementView - filtro inicial desde ruta', () {
    testWidgets('date filtra automáticamente el listado al día solicitado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeBehaviorManagementRepository()
        ..records = [
          _record(recordId: 'conducta-hoy-1', date: DateTime(2026, 10, 12)),
          _record(recordId: 'conducta-hoy-2', date: DateTime(2026, 10, 12)),
          _record(recordId: 'conducta-anterior', date: DateTime(2026, 10, 11)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.behavior}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behavior);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(find.text('2 de 3'), findsOneWidget);

      expect(
        find.byKey(const Key('behavior-record-conducta-hoy-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('behavior-record-conducta-hoy-2')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('behavior-record-conducta-anterior')),
        findsNothing,
      );

      expect(find.text('11 oct 2026'), findsNothing);

      expect(
        find.byKey(const Key('behavior-record-date-conducta-hoy-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('behavior-record-date-conducta-hoy-2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('behavior-filter-toggle-button')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('behavior-date-filter-card')),
        findsOneWidget,
      );

      final startDateButton = find.byKey(
        const Key('behavior-start-date-button'),
      );

      final endDateButton = find.byKey(const Key('behavior-end-date-button'));

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
        find.byKey(const Key('behavior-clear-date-filter')),
        findsOneWidget,
      );
    });

    testWidgets('sin date conserva la gestión normal sin filtro automático', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeBehaviorManagementRepository()
        ..records = [
          _record(recordId: 'conducta-hoy', date: DateTime(2026, 10, 12)),
          _record(recordId: 'conducta-anterior', date: DateTime(2026, 10, 11)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: AppRoutes.behavior,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behavior);

      expect(router.state.uri.queryParameters['date'], isNull);

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('behavior-record-conducta-hoy')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('behavior-record-conducta-anterior')),
        findsOneWidget,
      );

      expect(find.text('2'), findsWidgets);

      await tester.tap(find.byKey(const Key('behavior-filter-toggle-button')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('behavior-start-date-button'),
      );

      final endDateButton = find.byKey(const Key('behavior-end-date-button'));

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

      final repository = _FakeBehaviorManagementRepository()
        ..records = [
          _record(recordId: 'conducta-1', date: DateTime(2026, 10, 12)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.behavior}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.queryParameters['date'], '2026-02-31');

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('behavior-record-conducta-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('behavior-filter-toggle-button')));

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('behavior-start-date-button'),
      );

      final endDateButton = find.byKey(const Key('behavior-end-date-button'));

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
  _FakeBehaviorManagementRepository repository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
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
    ],
  );
}

BehaviorRecord _record({required String recordId, required DateTime date}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return BehaviorRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    category: BehaviorCategory.repetitiveBehavior,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  List<BehaviorRecord> records = [];

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return List<BehaviorRecord>.unmodifiable(records);
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {}
}
