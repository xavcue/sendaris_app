import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/exceptions/dysregulation_failure.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_management_repository.dart';
import 'package:sendaris/features/dysregulation/presentation/viewmodels/dysregulation_management_view_model.dart';

void main() {
  group('DysregulationManagementViewModel', () {
    test('carga y ordena por fecha efectiva y creación descendentes', () async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(
            recordId: 'dia-anterior',
            date: DateTime(2026, 9, 20),
            time: '18:00',
            createdAt: DateTime.utc(2026, 9, 20, 20),
          ),
          _record(
            recordId: 'sin-hora',
            date: DateTime(2026, 9, 22),
            time: null,
            createdAt: DateTime.utc(2026, 9, 22, 20),
          ),
          _record(
            recordId: 'manana',
            date: DateTime(2026, 9, 22),
            time: '08:30',
            createdAt: DateTime.utc(2026, 9, 22, 10),
          ),
          _record(
            recordId: 'tarde',
            date: DateTime(2026, 9, 22),
            time: '16:45',
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
        'tarde',
        'manana',
        'sin-hora',
        'dia-anterior',
      ]);

      expect(viewModel.totalRecordCount, 4);

      viewModel.dispose();
    });

    test(
      'desempata registros con el mismo instante por fecha de creación',
      () async {
        final repository = _FakeDysregulationManagementRepository()
          ..records = [
            _record(
              recordId: 'antiguo',
              date: DateTime(2026, 9, 22),
              time: '14:30',
              createdAt: DateTime.utc(2026, 9, 22, 15),
            ),
            _record(
              recordId: 'reciente',
              date: DateTime(2026, 9, 22),
              time: '14:30',
              createdAt: DateTime.utc(2026, 9, 22, 18),
            ),
          ];

        final viewModel = _createViewModel(repository);

        await viewModel.load();

        expect(viewModel.records.map((record) => record.recordId).toList(), [
          'reciente',
          'antiguo',
        ]);

        viewModel.dispose();
      },
    );

    test('el filtro por periodo incluye las fechas límite', () async {
      final repository = _FakeDysregulationManagementRepository()
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

      expect(viewModel.totalRecordCount, 3);

      viewModel.dispose();
    });

    test('permite aplicar únicamente Desde o únicamente Hasta', () async {
      final repository = _FakeDysregulationManagementRepository()
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

      viewModel.dispose();
    });

    test(
      'rechaza un periodo cuya fecha inicial es posterior a la final',
      () async {
        final repository = _FakeDysregulationManagementRepository();

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

        viewModel.dispose();
      },
    );

    test('quitar filtro limpia fechas pendientes y aplicadas', () async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [_record(recordId: 'desregulacion-1')];

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

      viewModel.dispose();
    });

    test('elimina físicamente el registro y lo retira de la lista', () async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'desregulacion-1'),
          _record(recordId: 'desregulacion-2'),
        ];

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      final record = viewModel.records.firstWhere(
        (currentRecord) => currentRecord.recordId == 'desregulacion-1',
      );

      final success = await viewModel.deleteDysregulation(record);

      expect(success, isTrue);

      expect(repository.deletedRecords, [
        (anonymousId: 'seguimiento-actual', recordId: 'desregulacion-1'),
      ]);

      expect(
        viewModel.records.map((currentRecord) => currentRecord.recordId),
        isNot(contains('desregulacion-1')),
      );

      expect(viewModel.totalRecordCount, 1);

      expect(viewModel.actionError, isNull);

      viewModel.dispose();
    });

    test(
      'un error al eliminar no retira el registro ni produce falso éxito',
      () async {
        final repository = _FakeDysregulationManagementRepository()
          ..records = [_record(recordId: 'desregulacion-1')]
          ..deleteError = const DysregulationFailure(
            'No fue posible eliminar el registro de desregulación.',
          );

        final viewModel = _createViewModel(repository);

        await viewModel.load();

        final record = viewModel.records.single;

        final success = await viewModel.deleteDysregulation(record);

        expect(success, isFalse);

        expect(viewModel.records, hasLength(1));

        expect(viewModel.records.single.recordId, 'desregulacion-1');

        expect(
          viewModel.actionError,
          'No fue posible eliminar el registro de desregulación.',
        );

        viewModel.dispose();
      },
    );

    test('un error de carga queda expuesto de forma controlada', () async {
      final repository = _FakeDysregulationManagementRepository()
        ..recoveryError = const DysregulationFailure(
          'No fue posible cargar los registros de desregulación.',
        );

      final viewModel = _createViewModel(repository);

      final success = await viewModel.load();

      expect(success, isFalse);

      expect(viewModel.hasLoaded, isFalse);

      expect(viewModel.isLoading, isFalse);

      expect(
        viewModel.loadError,
        'No fue posible cargar los registros de desregulación.',
      );

      viewModel.dispose();
    });

    test('marca únicamente el registro que se está eliminando', () async {
      final repository = _FakeDysregulationManagementRepository()
        ..records = [
          _record(recordId: 'desregulacion-1'),
          _record(recordId: 'desregulacion-2'),
        ]
        ..deleteGate = Completer<void>();

      final viewModel = _createViewModel(repository);

      await viewModel.load();

      final firstRecord = viewModel.records.firstWhere(
        (record) => record.recordId == 'desregulacion-1',
      );

      final deletion = viewModel.deleteDysregulation(firstRecord);

      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isDeleting('desregulacion-1'), isTrue);

      expect(viewModel.isDeleting('desregulacion-2'), isFalse);

      repository.deleteGate!.complete();

      expect(await deletion, isTrue);

      expect(viewModel.isDeleting('desregulacion-1'), isFalse);

      viewModel.dispose();
    });
  });
}

DysregulationManagementViewModel _createViewModel(
  _FakeDysregulationManagementRepository repository,
) {
  return DysregulationManagementViewModel(
    repository,
    anonymousId: 'seguimiento-actual',
  );
}

DysregulationRecord _record({
  required String recordId,
  DateTime? date,
  String? time,
  int? durationMinutes = 12,
  DysregulationIntensity? intensity = DysregulationIntensity.medium,
  String? context = 'Actividad cotidiana',
  String? observation = 'Registro ficticio.',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final creationTimestamp = createdAt ?? DateTime.utc(2026, 9, 22, 12);

  return DysregulationRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date ?? DateTime(2026, 9, 22),
    time: time,
    durationMinutes: durationMinutes,
    intensity: intensity,
    context: context,
    observation: observation,
    createdAt: creationTimestamp,
    updatedAt: updatedAt ?? creationTimestamp,
  );
}

class _FakeDysregulationManagementRepository
    implements DysregulationManagementRepository {
  List<DysregulationRecord> records = [];

  Object? recoveryError;
  Object? deleteError;

  Completer<void>? deleteGate;

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    final error = recoveryError;

    if (error != null) {
      throw error;
    }

    return List<DysregulationRecord>.from(records);
  }

  @override
  Future<void> deleteDysregulation({
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
  Future<void> saveDysregulation(DysregulationRecord record) async {}

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {}
}
