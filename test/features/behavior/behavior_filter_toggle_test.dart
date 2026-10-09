import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/presentation/viewmodels/behavior_management_view_model.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_management_view.dart';

void main() {
  group('BehaviorManagementView filtro contraíble', () {
    testWidgets('inicia contraído, se expande y vuelve a contraerse', (
      tester,
    ) async {
      final repository = _FakeBehaviorManagementRepository(
        records: [_record(recordId: 'conducta-1', date: DateTime(2026, 9, 22))],
      );

      await _pumpView(tester, repository);

      expect(find.byKey(const Key('behavior-date-filter-card')), findsNothing);

      expect(find.text('Filtrar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('behavior-filter-toggle-button')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('behavior-date-filter-card')),
        findsOneWidget,
      );

      expect(find.text('Periodo'), findsOneWidget);

      expect(find.text('Ocultar filtro'), findsOneWidget);

      await tester.tap(find.byKey(const Key('behavior-filter-toggle-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('behavior-date-filter-card')), findsNothing);

      expect(find.text('Filtrar'), findsOneWidget);
    });

    testWidgets(
      'un filtro aplicado se conserva al contraer y muestra Filtro activo',
      (tester) async {
        final repository = _FakeBehaviorManagementRepository(
          records: [
            _record(recordId: 'conducta-1', date: DateTime(2026, 9, 22)),
            _record(recordId: 'conducta-2', date: DateTime(2026, 9, 26)),
          ],
        );

        await _pumpView(tester, repository);

        await tester.tap(
          find.byKey(const Key('behavior-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        final scaffoldContext = tester.element(
          find.byKey(const Key('behavior-management-view')),
        );

        final viewModel = Provider.of<BehaviorManagementViewModel>(
          scaffoldContext,
          listen: false,
        );

        viewModel
          ..setPendingStartDate(DateTime(2026, 9, 26))
          ..setPendingEndDate(DateTime(2026, 9, 26))
          ..applyDateFilter();

        await tester.pump();

        expect(viewModel.filteredRecordCount, 1);

        await tester.tap(
          find.byKey(const Key('behavior-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('behavior-date-filter-card')),
          findsNothing,
        );

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(
          find.byKey(const Key('behavior-record-conducta-2')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('behavior-record-conducta-1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'el contador utiliza el mismo color destacado que los otros módulos',
      (tester) async {
        final repository = _FakeBehaviorManagementRepository(
          records: [
            _record(recordId: 'conducta-1', date: DateTime(2026, 9, 22)),
          ],
        );

        await _pumpView(tester, repository);

        final countFinder = find.byKey(const Key('behavior-record-count'));

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
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeBehaviorManagementRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BehaviorManagementView(
        repository: repository,
        anonymousId: 'seguimiento-actual',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

BehaviorRecord _record({required String recordId, required DateTime date}) {
  return BehaviorRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    time: '19:49',
    category: BehaviorCategory.repetitiveBehavior,
    durationMinutes: 10,
    intensity: BehaviorIntensity.medium,
    context: 'Cambio de actividad',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, date.day, 23, 49),
    updatedAt: DateTime.utc(2026, 9, date.day, 23, 49),
  );
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  _FakeBehaviorManagementRepository({required List<BehaviorRecord> records})
    : records = List<BehaviorRecord>.of(records);

  List<BehaviorRecord> records;

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return List.unmodifiable(records);
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {}
}
