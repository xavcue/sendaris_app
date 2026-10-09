import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/exceptions/feeding_failure.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_management_repository.dart';
import 'package:sendaris/features/feeding/presentation/viewmodels/feeding_management_view_model.dart';

void main() {
  group('FeedingManagementViewModel', () {
    test(
      'carga y ordena los registros por fecha y creación descendentes',
      () async {
        final repository = _FakeFeedingManagementRepository()
          ..records = [
            _record(
              recordId: 'antiguo',
              date: DateTime(2026, 9, 20),
              createdAt: DateTime.utc(2026, 9, 20, 10),
            ),
            _record(
              recordId: 'mismo-dia-antiguo',
              date: DateTime(2026, 9, 22),
              createdAt: DateTime.utc(2026, 9, 22, 10),
            ),
            _record(
              recordId: 'mismo-dia-reciente',
              date: DateTime(2026, 9, 22),
              createdAt: DateTime.utc(2026, 9, 22, 18),
            ),
          ];

        final viewModel = _createViewModel(repository);

        final success = await viewModel.load();

        expect(success, isTrue);

        expect(viewModel.hasLoaded, isTrue);

        expect(viewModel.isLoading, isFalse);

        expect(viewModel.loadError, isNull);

        expect(viewModel.records.map((record) => record.recordId).toList(), [
          'mismo-dia-reciente',
          'mismo-dia-antiguo',
          'antiguo',
        ]);
      },
    );

    test('el filtro por periodo incluye las fechas límite', () async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
          _record(recordId: 'dia-21', date: DateTime(2026, 9, 21)),
          _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
        ];

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 21));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.records.map((record) => record.recordId).toSet(), {
        'dia-20',
        'dia-21',
      });

      expect(viewModel.recordCount, 2);
    });

    test('permite aplicar únicamente Desde o únicamente Hasta', () async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
          _record(recordId: 'dia-21', date: DateTime(2026, 9, 21)),
          _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
        ];

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 21));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.records.map((record) => record.recordId).toSet(), {
        'dia-21',
        'dia-22',
      });

      viewModel.clearDateFilter();

      viewModel.setPendingEndDate(DateTime(2026, 9, 21));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.records.map((record) => record.recordId).toSet(), {
        'dia-20',
        'dia-21',
      });
    });

    test(
      'rechaza un periodo cuya fecha inicial es posterior a la final',
      () async {
        final repository = _FakeFeedingManagementRepository();

        final viewModel = _createViewModel(repository);

        await viewModel.load();

        viewModel.setPendingStartDate(DateTime(2026, 9, 22));

        viewModel.setPendingEndDate(DateTime(2026, 9, 20));

        expect(viewModel.applyDateFilter(), isFalse);

        expect(
          viewModel.filterError,
          'La fecha inicial no puede ser posterior '
          'a la fecha final.',
        );

        expect(viewModel.hasAppliedDateFilter, isFalse);
      },
    );

    test('quitar filtro limpia fechas pendientes y aplicadas', () async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [_record(recordId: 'alimentacion-1')];

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 25));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.hasAppliedDateFilter, isTrue);

      viewModel.clearDateFilter();

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);

      expect(viewModel.appliedStartDate, isNull);

      expect(viewModel.appliedEndDate, isNull);

      expect(viewModel.hasPendingDateFilter, isFalse);

      expect(viewModel.hasAppliedDateFilter, isFalse);

      expect(viewModel.filterError, isNull);
    });

    test('elimina físicamente el registro y lo retira de la lista', () async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'alimentacion-1'),
          _record(recordId: 'alimentacion-2'),
        ];

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      final record = viewModel.records.firstWhere(
        (currentRecord) => currentRecord.recordId == 'alimentacion-1',
      );

      final success = await viewModel.deleteFeeding(record);

      expect(success, isTrue);

      expect(repository.deletedRecords, [
        (anonymousId: 'seguimiento-actual', recordId: 'alimentacion-1'),
      ]);

      expect(
        viewModel.records.map((currentRecord) => currentRecord.recordId),
        isNot(contains('alimentacion-1')),
      );

      expect(viewModel.actionError, isNull);
    });

    test(
      'un error al eliminar no retira el registro ni produce falso éxito',
      () async {
        final repository = _FakeFeedingManagementRepository()
          ..records = [_record(recordId: 'alimentacion-1')]
          ..deleteError = const FeedingFailure(
            'No fue posible eliminar '
            'el registro de alimentación.',
          );

        final viewModel = _createViewModel(repository);

        await viewModel.load();

        final record = viewModel.records.single;

        final success = await viewModel.deleteFeeding(record);

        expect(success, isFalse);

        expect(viewModel.records, hasLength(1));

        expect(viewModel.records.single.recordId, 'alimentacion-1');

        expect(
          viewModel.actionError,
          'No fue posible eliminar '
          'el registro de alimentación.',
        );
      },
    );

    test('un error de carga queda expuesto de forma controlada', () async {
      final repository = _FakeFeedingManagementRepository()
        ..recoveryError = const FeedingFailure(
          'No fue posible cargar '
          'los registros de alimentación.',
        );

      final viewModel = _createViewModel(repository);

      final success = await viewModel.load();

      expect(success, isFalse);

      expect(viewModel.hasLoaded, isFalse);

      expect(viewModel.isLoading, isFalse);

      expect(
        viewModel.loadError,
        'No fue posible cargar '
        'los registros de alimentación.',
      );
    });

    test('marca únicamente el registro que se está eliminando', () async {
      final repository = _FakeFeedingManagementRepository()
        ..records = [
          _record(recordId: 'alimentacion-1'),
          _record(recordId: 'alimentacion-2'),
        ]
        ..deleteGate = Completer<void>();

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      final firstRecord = viewModel.records.firstWhere(
        (record) => record.recordId == 'alimentacion-1',
      );

      final deletion = viewModel.deleteFeeding(firstRecord);

      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isDeleting('alimentacion-1'), isTrue);

      expect(viewModel.isDeleting('alimentacion-2'), isFalse);

      repository.deleteGate!.complete();

      expect(await deletion, isTrue);

      expect(viewModel.isDeleting('alimentacion-1'), isFalse);
    });
  });
}

FeedingManagementViewModel _createViewModel(
  _FakeFeedingManagementRepository repository,
) {
  return FeedingManagementViewModel(
    repository,
    anonymousId: 'seguimiento-actual',
  );
}

FeedingRecord _record({
  required String recordId,
  DateTime? date,
  FeedingCategory category = FeedingCategory.lunch,
  String? observation = 'Registro ficticio.',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final creationTimestamp = createdAt ?? DateTime.utc(2026, 9, 22, 12);

  return FeedingRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date ?? DateTime(2026, 9, 22),
    category: category,
    observation: observation,
    createdAt: creationTimestamp,
    updatedAt: updatedAt ?? creationTimestamp,
  );
}

class _FakeFeedingManagementRepository implements FeedingManagementRepository {
  List<FeedingRecord> records = [];

  Object? recoveryError;
  Object? deleteError;

  Completer<void>? deleteGate;

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    final error = recoveryError;

    if (error != null) {
      throw error;
    }

    return List<FeedingRecord>.from(records);
  }

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {
    final gate = deleteGate;

    if (gate != null) {
      await gate.future;
    }

    final error = deleteError;

    if (error != null) {
      throw error;
    }

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveFeeding(FeedingRecord record) async {}

  @override
  Future<void> updateFeeding(FeedingRecord record) async {}
}
