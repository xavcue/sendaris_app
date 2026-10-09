import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/exceptions/sleep_failure.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_management_repository.dart';
import 'package:sendaris/features/sleep/presentation/viewmodels/sleep_management_view_model.dart';

void main() {
  group('SleepManagementViewModel', () {
    late _FakeSleepManagementRepository repository;

    late SleepManagementViewModel viewModel;

    setUp(() {
      repository = _FakeSleepManagementRepository();

      viewModel = SleepManagementViewModel(
        repository,
        anonymousId: 'seguimiento-actual',
      );
    });

    test('recupera únicamente el seguimiento actual y ordena por inicio descendente', () async {
      repository.records = [
        _record(
          recordId: 'sueno-antiguo',
          date: DateTime(2026, 9, 20),
          startTime: '22:00',
          createdAt: DateTime.utc(2026, 9, 21, 8),
        ),
        _record(
          recordId: 'sueno-reciente',
          date: DateTime(2026, 9, 22),
          startTime: '23:00',
          createdAt: DateTime.utc(2026, 9, 23, 8),
        ),
        _record(
          recordId: 'otro-seguimiento',
          anonymousId: 'seguimiento-distinto',
          date: DateTime(2026, 9, 23),
          startTime: '23:30',
          createdAt: DateTime.utc(2026, 9, 24, 8),
        ),
      ];

      final success = await viewModel.load();

      expect(success, isTrue);

      expect(viewModel.hasLoaded, isTrue);

      expect(viewModel.records.map((record) => record.recordId).toList(), [
        'sueno-reciente',
        'sueno-antiguo',
      ]);

      expect(repository.requestedAnonymousIds, ['seguimiento-actual']);
    });

    test(
      'usa fecha de creación descendente para desempatar el mismo inicio',
      () async {
        repository.records = [
          _record(
            recordId: 'primero-creado',
            date: DateTime(2026, 9, 22),
            startTime: '22:00',
            createdAt: DateTime.utc(2026, 9, 23, 8),
          ),
          _record(
            recordId: 'ultimo-creado',
            date: DateTime(2026, 9, 22),
            startTime: '22:00',
            createdAt: DateTime.utc(2026, 9, 23, 10),
          ),
        ];

        await viewModel.load();

        expect(viewModel.records.map((record) => record.recordId).toList(), [
          'ultimo-creado',
          'primero-creado',
        ]);
      },
    );

    test('aplica un periodo inclusivo por fecha del sueño', () async {
      repository.records = [
        _record(recordId: 'antes', date: DateTime(2026, 9, 9)),
        _record(recordId: 'inicio', date: DateTime(2026, 9, 10)),
        _record(recordId: 'medio', date: DateTime(2026, 9, 12)),
        _record(recordId: 'fin', date: DateTime(2026, 9, 15)),
        _record(recordId: 'despues', date: DateTime(2026, 9, 16)),
      ];

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 10));

      viewModel.setPendingEndDate(DateTime(2026, 9, 15));

      final applied = viewModel.applyDateFilter();

      expect(applied, isTrue);

      expect(viewModel.records.map((record) => record.recordId).toSet(), {
        'inicio',
        'medio',
        'fin',
      });
    });

    test('rechaza un periodo donde Desde es posterior a Hasta', () {
      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 10));

      final applied = viewModel.applyDateFilter();

      expect(applied, isFalse);

      expect(
        viewModel.filterError,
        'La fecha inicial no puede ser posterior '
        'a la fecha final.',
      );

      expect(viewModel.hasAppliedDateFilter, isFalse);
    });

    test('quitar filtro restaura todos los registros', () async {
      repository.records = [
        _record(recordId: 'sueno-1', date: DateTime(2026, 9, 10)),
        _record(recordId: 'sueno-2', date: DateTime(2026, 9, 20)),
      ];

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 15));

      viewModel.applyDateFilter();

      expect(viewModel.recordCount, 1);

      viewModel.clearDateFilter();

      expect(viewModel.recordCount, 2);

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.appliedStartDate, isNull);

      expect(viewModel.filterError, isNull);
    });

    test('elimina remotamente y retira el sueño del listado local', () async {
      final record = _record(recordId: 'sueno-eliminar');

      repository.records = [record, _record(recordId: 'sueno-conservar')];

      await viewModel.load();

      final success = await viewModel.deleteSleep(record);

      expect(success, isTrue);

      expect(repository.deletedRecords, [
        (anonymousId: 'seguimiento-actual', recordId: 'sueno-eliminar'),
      ]);

      expect(
        viewModel.records.map((current) => current.recordId),
        isNot(contains('sueno-eliminar')),
      );

      expect(viewModel.actionError, isNull);
    });

    test(
      'si eliminar falla conserva el registro y expone el error controlado',
      () async {
        final record = _record(recordId: 'sueno-1');

        repository.records = [record];

        await viewModel.load();

        repository.deleteFailure = const SleepFailure(
          'No fue posible eliminar el registro de sueño.',
        );

        final success = await viewModel.deleteSleep(record);

        expect(success, isFalse);

        expect(viewModel.records, contains(record));

        expect(
          viewModel.actionError,
          'No fue posible eliminar el registro de sueño.',
        );

        expect(viewModel.isDeleting(record.recordId), isFalse);
      },
    );

    test(
      'un reload fallido conserva los registros previamente cargados',
      () async {
        repository.records = [_record(recordId: 'sueno-existente')];

        await viewModel.load();

        repository.recoveryFailure = const SleepFailure(
          'No fue posible cargar los registros de sueño.',
        );

        final success = await viewModel.reload();

        expect(success, isFalse);

        expect(
          viewModel.records.map((record) => record.recordId),
          contains('sueno-existente'),
        );

        expect(
          viewModel.loadError,
          'No fue posible cargar los registros de sueño.',
        );
      },
    );

    test('un reload exitoso mantiene el periodo aplicado', () async {
      repository.records = [
        _record(recordId: 'dentro-1', date: DateTime(2026, 9, 12)),
        _record(recordId: 'fuera-1', date: DateTime(2026, 9, 20)),
      ];

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 10));

      viewModel.setPendingEndDate(DateTime(2026, 9, 15));

      viewModel.applyDateFilter();

      repository.records = [
        _record(recordId: 'dentro-2', date: DateTime(2026, 9, 14)),
        _record(recordId: 'fuera-2', date: DateTime(2026, 9, 22)),
      ];

      final success = await viewModel.reload();

      expect(success, isTrue);

      expect(viewModel.hasAppliedDateFilter, isTrue);

      expect(viewModel.records.map((record) => record.recordId).toList(), [
        'dentro-2',
      ]);
    });
  });
}

SleepRecord _record({
  required String recordId,
  String anonymousId = 'seguimiento-actual',
  DateTime? date,
  String startTime = '22:00',
  String endTime = '06:00',
  int durationMinutes = 480,
  String? observation = 'Registro ficticio.',
  DateTime? createdAt,
}) {
  final creationTimestamp = createdAt ?? DateTime.utc(2026, 9, 23, 8);

  return SleepRecord(
    recordId: recordId,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 9, 22),
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    observation: observation,
    createdAt: creationTimestamp,
    updatedAt: creationTimestamp,
  );
}

class _FakeSleepManagementRepository implements SleepManagementRepository {
  List<SleepRecord> records = [];

  final List<String> requestedAnonymousIds = [];

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  SleepFailure? recoveryFailure;

  SleepFailure? deleteFailure;

  @override
  Future<void> saveSleep(SleepRecord record) async {}

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    requestedAnonymousIds.add(anonymousId);

    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> updateSleep(SleepRecord record) async {}

  @override
  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  }) async {
    final failure = deleteFailure;

    if (failure != null) {
      throw failure;
    }

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));
  }
}
