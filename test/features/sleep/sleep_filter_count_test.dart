import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_management_repository.dart';
import 'package:sendaris/features/sleep/presentation/viewmodels/sleep_management_view_model.dart';
import 'package:sendaris/features/sleep/presentation/views/sleep_management_view.dart';

void main() {
  testWidgets(
    'el contador muestra visibles de total cuando existe un filtro aplicado',
    (tester) async {
      final repository = _FakeSleepManagementRepository(
        records: [
          _record(recordId: 'sueno-22', date: DateTime(2026, 9, 22)),
          _record(recordId: 'sueno-24', date: DateTime(2026, 9, 24)),
          _record(recordId: 'sueno-26', date: DateTime(2026, 9, 26)),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SleepManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('sleep-record-count')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      final context = tester.element(
        find.byKey(const Key('sleep-management-list')),
      );

      final viewModel = Provider.of<SleepManagementViewModel>(
        context,
        listen: false,
      );

      expect(viewModel.totalRecordCount, 3);

      viewModel
        ..setPendingStartDate(DateTime(2026, 9, 23))
        ..setPendingEndDate(DateTime(2026, 9, 26));

      expect(viewModel.applyDateFilter(), isTrue);

      await tester.pump();

      expect(viewModel.recordCount, 2);

      expect(viewModel.totalRecordCount, 3);

      expect(
        find.descendant(
          of: find.byKey(const Key('sleep-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      viewModel.clearDateFilter();

      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('sleep-record-count')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      expect(find.text('2 de 3'), findsNothing);
    },
  );
}

SleepRecord _record({required String recordId, required DateTime date}) {
  return SleepRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    startTime: '22:00',
    endTime: '06:00',
    durationMinutes: 480,
    createdAt: DateTime.utc(2026, 9, date.day, 8),
    updatedAt: DateTime.utc(2026, 9, date.day, 8),
  );
}

class _FakeSleepManagementRepository implements SleepManagementRepository {
  _FakeSleepManagementRepository({required List<SleepRecord> records})
    : _records = List<SleepRecord>.from(records);

  final List<SleepRecord> _records;

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return List.unmodifiable(_records);
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
    _records.removeWhere((record) => record.recordId == recordId);
  }
}
