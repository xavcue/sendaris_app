import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/exceptions/behavior_failure.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/presentation/viewmodels/behavior_management_view_model.dart';

void main() {
  group('BehaviorManagementViewModel', () {
    late _FakeBehaviorManagementRepository repository;

    late BehaviorManagementViewModel viewModel;

    setUp(() {
      repository = _FakeBehaviorManagementRepository();

      viewModel = BehaviorManagementViewModel(
        repository,
        anonymousId: 'seguimiento-actual',
      );
    });

    test('carga únicamente las conductas del seguimiento actual', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'actual-1',
          anonymousId: 'seguimiento-actual',
          date: DateTime(2026, 9, 20),
        ),
        _record(
          recordId: 'otro-1',
          anonymousId: 'otro-seguimiento',
          date: DateTime(2026, 9, 21),
        ),
      ];

      final success = await viewModel.initialize();

      expect(success, isTrue);

      expect(viewModel.records.length, 1);

      expect(viewModel.records.single.recordId, 'actual-1');

      expect(viewModel.hasLoaded, isTrue);

      expect(viewModel.errorMessage, isNull);
    });

    test('ordena las conductas desde el evento más reciente', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'antigua',
          date: DateTime(2026, 9, 20),
          time: '08:00',
        ),
        _record(
          recordId: 'reciente',
          date: DateTime(2026, 9, 22),
          time: '17:30',
        ),
        _record(
          recordId: 'intermedia',
          date: DateTime(2026, 9, 21),
          time: '12:00',
        ),
      ];

      await viewModel.initialize();

      expect(viewModel.records.map((record) => record.recordId).toList(), [
        'reciente',
        'intermedia',
        'antigua',
      ]);
    });

    test(
      'usa fechaCreacion como desempate para eventos con la misma fecha y hora',
      () async {
        repository.recordsToRecover = [
          _record(
            recordId: 'creado-primero',
            date: DateTime(2026, 9, 22),
            time: '15:00',
            createdAt: DateTime.utc(2026, 9, 22, 20),
          ),
          _record(
            recordId: 'creado-despues',
            date: DateTime(2026, 9, 22),
            time: '15:00',
            createdAt: DateTime.utc(2026, 9, 22, 21),
          ),
        ];

        await viewModel.initialize();

        expect(viewModel.records.map((record) => record.recordId).toList(), [
          'creado-despues',
          'creado-primero',
        ]);
      },
    );

    test('filtra de forma inclusiva entre fecha inicial y final', () async {
      repository.recordsToRecover = [
        _record(recordId: '19', date: DateTime(2026, 9, 19)),
        _record(recordId: '20', date: DateTime(2026, 9, 20)),
        _record(recordId: '21', date: DateTime(2026, 9, 21)),
        _record(recordId: '22', date: DateTime(2026, 9, 22)),
        _record(recordId: '23', date: DateTime(2026, 9, 23)),
      ];

      await viewModel.initialize();

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 22));

      final success = viewModel.applyDateFilter();

      expect(success, isTrue);

      expect(
        viewModel.filteredRecords.map((record) => record.recordId).toSet(),
        {'20', '21', '22'},
      );

      expect(viewModel.hasActiveDateFilter, isTrue);
    });

    test(
      'rechaza un periodo cuya fecha inicial sea posterior a la final',
      () async {
        repository.recordsToRecover = [
          _record(recordId: 'registro-1', date: DateTime(2026, 9, 20)),
        ];

        await viewModel.initialize();

        viewModel.setPendingStartDate(DateTime(2026, 9, 22));

        viewModel.setPendingEndDate(DateTime(2026, 9, 20));

        final success = viewModel.applyDateFilter();

        expect(success, isFalse);

        expect(viewModel.filterErrorMessage, isNotNull);

        expect(viewModel.hasActiveDateFilter, isFalse);
      },
    );

    test('quitar filtro restaura todos los registros', () async {
      repository.recordsToRecover = [
        _record(recordId: '20', date: DateTime(2026, 9, 20)),
        _record(recordId: '22', date: DateTime(2026, 9, 22)),
      ];

      await viewModel.initialize();

      viewModel.setPendingStartDate(DateTime(2026, 9, 22));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.filteredRecords.length, 1);

      viewModel.clearDateFilter();

      expect(viewModel.filteredRecords.length, 2);

      expect(viewModel.hasActiveDateFilter, isFalse);

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);
    });

    test(
      'eliminar borra el registro remoto y lo retira del listado local',
      () async {
        final record = _record(
          recordId: 'conducta-eliminar',
          date: DateTime(2026, 9, 22),
        );

        repository.recordsToRecover = [
          record,
          _record(recordId: 'conducta-conservar', date: DateTime(2026, 9, 21)),
        ];

        await viewModel.initialize();

        final success = await viewModel.deleteBehavior(record);

        expect(success, isTrue);

        expect(repository.deletedRecords, [
          (anonymousId: 'seguimiento-actual', recordId: 'conducta-eliminar'),
        ]);

        expect(viewModel.records.map((current) => current.recordId).toList(), [
          'conducta-conservar',
        ]);

        expect(viewModel.actionErrorMessage, isNull);
      },
    );

    test('si eliminar falla conserva el registro y expone el error', () async {
      final record = _record(
        recordId: 'conducta-conservar',
        date: DateTime(2026, 9, 22),
      );

      repository.recordsToRecover = [record];

      await viewModel.initialize();

      repository.deleteFailure = const BehaviorFailure(
        'No fue posible eliminar la conducta.',
      );

      final success = await viewModel.deleteBehavior(record);

      expect(success, isFalse);

      expect(viewModel.records.length, 1);

      expect(viewModel.records.single.recordId, 'conducta-conservar');

      expect(
        viewModel.actionErrorMessage,
        'No fue posible eliminar la conducta.',
      );
    });

    test(
      'si una recarga falla conserva los registros previamente cargados',
      () async {
        repository.recordsToRecover = [
          _record(recordId: 'registro-existente', date: DateTime(2026, 9, 22)),
        ];

        expect(await viewModel.initialize(), isTrue);

        repository.recoveryFailure = const BehaviorFailure(
          'No fue posible cargar las conductas.',
        );

        expect(await viewModel.reload(), isFalse);

        expect(viewModel.records.length, 1);

        expect(viewModel.records.single.recordId, 'registro-existente');

        expect(viewModel.errorMessage, 'No fue posible cargar las conductas.');
      },
    );
  });
}

BehaviorRecord _record({
  required String recordId,
  required DateTime date,
  String anonymousId = 'seguimiento-actual',
  String? time,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 9, 20, 18);

  return BehaviorRecord(
    recordId: recordId,
    anonymousId: anonymousId,
    date: date,
    time: time,
    category: BehaviorCategory.repetitiveBehavior,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  List<BehaviorRecord> recordsToRecover = [];

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  BehaviorFailure? recoveryFailure;

  BehaviorFailure? deleteFailure;

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List.unmodifiable(recordsToRecover);
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    final failure = deleteFailure;

    if (failure != null) {
      throw failure;
    }

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {}
}
