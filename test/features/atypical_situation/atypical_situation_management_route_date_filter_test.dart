import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_management_repository.dart';
import 'package:sendaris/features/atypical_situation/presentation/views/atypical_situation_management_view.dart';

void main() {
  group('AtypicalSituationManagementView - filtro inicial desde ruta', () {
    testWidgets('date filtra automáticamente el listado al día solicitado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'situacion-hoy-1', date: DateTime(2026, 10, 12)),
          _record(recordId: 'situacion-hoy-2', date: DateTime(2026, 10, 12)),
          _record(recordId: 'situacion-anterior', date: DateTime(2026, 10, 11)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.atypicalSituation}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.atypicalSituation);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('atypical-situation-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-hoy-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-hoy-2')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-anterior')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('atypical-situation-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('atypical-situation-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('atypical-situation-end-date-button'),
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
        find.byKey(const Key('atypical-situation-clear-date-filter')),
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

      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'situacion-hoy', date: DateTime(2026, 10, 12)),
          _record(recordId: 'situacion-anterior', date: DateTime(2026, 10, 11)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: AppRoutes.atypicalSituation,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.atypicalSituation);

      expect(router.state.uri.queryParameters['date'], isNull);

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-hoy')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-anterior')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('atypical-situation-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('atypical-situation-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('atypical-situation-end-date-button'),
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

      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'situacion-1', date: DateTime(2026, 10, 12)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.atypicalSituation}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.queryParameters['date'], '2026-02-31');

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('atypical-situation-record-situacion-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('atypical-situation-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('atypical-situation-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('atypical-situation-end-date-button'),
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
  _FakeAtypicalSituationManagementRepository repository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.atypicalSituation,
        builder: (context, state) {
          return AtypicalSituationManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
    ],
  );
}

AtypicalSituationRecord _record({
  required String recordId,
  required DateTime date,
}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return AtypicalSituationRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    category: AtypicalSituationCategory.environmentChange,
    observation: 'Observación descriptiva de prueba.',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeAtypicalSituationManagementRepository
    implements AtypicalSituationManagementRepository {
  List<AtypicalSituationRecord> records = [];

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    return List<AtypicalSituationRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {}

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}
