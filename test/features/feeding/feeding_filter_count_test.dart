import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_management_repository.dart';
import 'package:sendaris/features/feeding/presentation/viewmodels/feeding_management_view_model.dart';
import 'package:sendaris/features/feeding/presentation/views/feeding_management_view.dart';

void main() {
  testWidgets(
    'el contador muestra visibles de total cuando existe un filtro aplicado',
    (tester) async {
      final repository = _FakeFeedingManagementRepository(
        records: [
          _record(recordId: 'alimentacion-18', date: DateTime(2026, 9, 18)),
          _record(recordId: 'alimentacion-22', date: DateTime(2026, 9, 22)),
          _record(recordId: 'alimentacion-26', date: DateTime(2026, 9, 26)),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FeedingManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('feeding-record-count')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      final context = tester.element(
        find.byKey(const Key('feeding-management-list')),
      );

      final viewModel = Provider.of<FeedingManagementViewModel>(
        context,
        listen: false,
      );

      expect(viewModel.totalRecordCount, 3);

      viewModel
        ..setPendingStartDate(DateTime(2026, 9, 20))
        ..setPendingEndDate(DateTime(2026, 9, 28));

      expect(viewModel.applyDateFilter(), isTrue);

      await tester.pump();

      expect(viewModel.recordCount, 2);

      expect(viewModel.totalRecordCount, 3);

      expect(
        find.descendant(
          of: find.byKey(const Key('feeding-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      viewModel.clearDateFilter();

      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('feeding-record-count')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      expect(find.text('2 de 3'), findsNothing);
    },
  );
}

FeedingRecord _record({required String recordId, required DateTime date}) {
  return FeedingRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    category: FeedingCategory.lunch,
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, date.day, 18),
    updatedAt: DateTime.utc(2026, 9, date.day, 18),
  );
}

class _FakeFeedingManagementRepository implements FeedingManagementRepository {
  _FakeFeedingManagementRepository({required List<FeedingRecord> records})
    : _records = List<FeedingRecord>.from(records);

  final List<FeedingRecord> _records;

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return List.unmodifiable(_records);
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
    _records.removeWhere((record) => record.recordId == recordId);
  }
}
