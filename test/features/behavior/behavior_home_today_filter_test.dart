import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_management_view.dart';

void main() {
  testWidgets(
    'entrada contextual desde Inicio filtra Conducta por la fecha recibida',
    (tester) async {
      final repository = _FakeBehaviorManagementRepository(
        records: [
          _record(recordId: 'conducta-anterior', date: DateTime(2026, 10, 12)),
          _record(recordId: 'conducta-hoy-1', date: DateTime(2026, 10, 13)),
          _record(recordId: 'conducta-hoy-2', date: DateTime(2026, 10, 13)),
        ],
      );

      final router = GoRouter(
        initialLocation: '${AppRoutes.behavior}?date=2026-10-13',
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

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtro activo'), findsOneWidget);

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

      expect(
        find.descendant(
          of: find.byKey(const Key('behavior-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('behavior-filter-toggle-button')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('behavior-date-filter-card')),
        findsOneWidget,
      );

      expect(find.text('13 oct 2026'), findsNWidgets(2));
    },
  );

  testWidgets(
    'entrada normal a Conducta conserva el listado sin filtro automático',
    (tester) async {
      final repository = _FakeBehaviorManagementRepository(
        records: [
          _record(recordId: 'conducta-12', date: DateTime(2026, 10, 12)),
          _record(recordId: 'conducta-13', date: DateTime(2026, 10, 13)),
        ],
      );

      final router = GoRouter(
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
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(
        find.byKey(const Key('behavior-record-conducta-12')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('behavior-record-conducta-13')),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('behavior-record-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      expect(find.text('2 de 2'), findsNothing);
    },
  );
}

BehaviorRecord _record({required String recordId, required DateTime date}) {
  return BehaviorRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    time: '10:30',
    category: BehaviorCategory.aggressionIrritability,
    createdAt: DateTime.utc(date.year, date.month, date.day, 15, 30),
    updatedAt: DateTime.utc(date.year, date.month, date.day, 15, 30),
  );
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  _FakeBehaviorManagementRepository({required List<BehaviorRecord> records})
    : _records = List<BehaviorRecord>.from(records);

  final List<BehaviorRecord> _records;

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return List<BehaviorRecord>.unmodifiable(_records);
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {}

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    _records.removeWhere((record) => record.recordId == recordId);
  }
}
