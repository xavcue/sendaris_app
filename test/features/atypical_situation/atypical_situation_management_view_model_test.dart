import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/exceptions/atypical_situation_failure.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_management_repository.dart';
import 'package:sendaris/features/atypical_situation/presentation/viewmodels/atypical_situation_management_view_model.dart';

void main() {
  group('AtypicalSituationManagementViewModel', () {
    test('carga y ordena los registros por fecha descendente', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'antiguo', date: DateTime(2026, 9, 10)),
          _record(recordId: 'reciente', date: DateTime(2026, 9, 22)),
        ];

      final viewModel = _viewModel(repository);

      final result = await viewModel.load();

      expect(result, isTrue);

      expect(viewModel.hasLoaded, isTrue);

      expect(viewModel.records.map((record) => record.recordId), [
        'reciente',
        'antiguo',
      ]);

      expect(repository.recoveredAnonymousId, 'seguimiento-actual');

      viewModel.dispose();
    });

    test('desempata registros del mismo día por fecha de creación', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(
            recordId: 'primero',
            date: DateTime(2026, 9, 22),
            createdAt: DateTime.utc(2026, 9, 22, 12),
          ),
          _record(
            recordId: 'segundo',
            date: DateTime(2026, 9, 22),
            createdAt: DateTime.utc(2026, 9, 22, 18),
          ),
        ];

      final viewModel = _viewModel(repository);

      await viewModel.load();

      expect(viewModel.records.map((record) => record.recordId), [
        'segundo',
        'primero',
      ]);

      viewModel.dispose();
    });

    test('el filtro por fechas es inclusivo', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'dia-10', date: DateTime(2026, 9, 10)),
          _record(recordId: 'dia-15', date: DateTime(2026, 9, 15)),
          _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
        ];

      final viewModel = _viewModel(repository);

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 10, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 15, 8));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.records.map((record) => record.recordId), [
        'dia-15',
        'dia-10',
      ]);

      expect(viewModel.recordCount, 2);

      expect(viewModel.totalRecordCount, 3);

      viewModel.dispose();
    });

    test('rechaza un periodo con fecha inicial posterior a la final', () async {
      final repository = _FakeAtypicalSituationManagementRepository();

      final viewModel = _viewModel(repository);

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 10));

      expect(viewModel.applyDateFilter(), isFalse);

      expect(
        viewModel.filterError,
        'La fecha inicial no puede ser posterior '
        'a la fecha final.',
      );

      viewModel.dispose();
    });

    test('quitar filtro limpia valores pendientes y aplicados', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'registro-1')];

      final viewModel = _viewModel(repository);

      await viewModel.load();

      viewModel.setPendingStartDate(DateTime(2026, 9, 1));

      viewModel.setPendingEndDate(DateTime(2026, 9, 30));

      viewModel.applyDateFilter();

      expect(viewModel.hasAppliedDateFilter, isTrue);

      viewModel.clearDateFilter();

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);

      expect(viewModel.appliedStartDate, isNull);

      expect(viewModel.appliedEndDate, isNull);

      expect(viewModel.hasAppliedDateFilter, isFalse);

      viewModel.dispose();
    });

    test('elimina un registro y lo retira del listado local', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'registro-1'),
          _record(recordId: 'registro-2'),
        ];

      final viewModel = _viewModel(repository);

      await viewModel.load();

      final record = viewModel.records.firstWhere(
        (item) => item.recordId == 'registro-1',
      );

      final result = await viewModel.deleteAtypicalSituation(record);

      expect(result, isTrue);

      expect(repository.deletedAnonymousId, 'seguimiento-actual');

      expect(repository.deletedRecordId, 'registro-1');

      expect(
        viewModel.records.any((item) => item.recordId == 'registro-1'),
        isFalse,
      );

      expect(viewModel.totalRecordCount, 1);

      viewModel.dispose();
    });

    test('expone error controlado cuando falla la eliminación', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [_record(recordId: 'registro-1')]
        ..deleteFailure = const AtypicalSituationFailure(
          'No tienes autorización para eliminar esta situación.',
        );

      final viewModel = _viewModel(repository);

      await viewModel.load();

      final result = await viewModel.deleteAtypicalSituation(
        viewModel.records.single,
      );

      expect(result, isFalse);

      expect(
        viewModel.actionError,
        'No tienes autorización para eliminar esta situación.',
      );

      expect(viewModel.totalRecordCount, 1);

      viewModel.clearActionError();

      expect(viewModel.actionError, isNull);

      viewModel.dispose();
    });

    test('expone error controlado cuando falla la carga', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..recoveryFailure = const AtypicalSituationFailure(
          'No fue posible recuperar los registros.',
        );

      final viewModel = _viewModel(repository);

      final result = await viewModel.load();

      expect(result, isFalse);

      expect(viewModel.loadError, 'No fue posible recuperar los registros.');

      expect(viewModel.isLoading, isFalse);

      viewModel.dispose();
    });

    test('reload vuelve a consultar el repositorio', () async {
      final repository = _FakeAtypicalSituationManagementRepository();

      final viewModel = _viewModel(repository);

      await viewModel.load();
      await viewModel.reload();

      expect(repository.recoveryCalls, 2);

      viewModel.dispose();
    });

    test('distingue estado vacío de resultados vacíos por filtro', () async {
      final repository = _FakeAtypicalSituationManagementRepository()
        ..records = [
          _record(recordId: 'registro-1', date: DateTime(2026, 9, 22)),
        ];

      final viewModel = _viewModel(repository);

      await viewModel.load();

      expect(viewModel.isEmpty, isFalse);

      viewModel.setPendingStartDate(DateTime(2026, 10, 1));

      viewModel.applyDateFilter();

      expect(viewModel.hasNoFilterResults, isTrue);

      expect(viewModel.recordCount, 0);

      expect(viewModel.totalRecordCount, 1);

      viewModel.dispose();
    });
  });
}

AtypicalSituationManagementViewModel _viewModel(
  _FakeAtypicalSituationManagementRepository repository,
) {
  return AtypicalSituationManagementViewModel(
    repository,
    anonymousId: 'seguimiento-actual',
  );
}

AtypicalSituationRecord _record({
  required String recordId,
  DateTime? date,
  DateTime? createdAt,
  AtypicalSituationCategory category =
      AtypicalSituationCategory.unexpectedEvent,
  String observation = 'Situación ficticia para pruebas.',
}) {
  final creationDate = createdAt ?? DateTime.utc(2026, 9, 22, 12);

  return AtypicalSituationRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date ?? DateTime(2026, 9, 22),
    category: category,
    observation: observation,
    createdAt: creationDate,
    updatedAt: creationDate,
  );
}

class _FakeAtypicalSituationManagementRepository
    implements AtypicalSituationManagementRepository {
  List<AtypicalSituationRecord> records = [];

  Object? recoveryFailure;
  Object? deleteFailure;

  int recoveryCalls = 0;

  String? recoveredAnonymousId;
  String? deletedAnonymousId;
  String? deletedRecordId;

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    recoveryCalls++;

    recoveredAnonymousId = anonymousId;

    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List<AtypicalSituationRecord>.from(records);
  }

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {
    final failure = deleteFailure;

    if (failure != null) {
      throw failure;
    }

    deletedAnonymousId = anonymousId;

    deletedRecordId = recordId;

    records = records.where((record) => record.recordId != recordId).toList();
  }

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {}
}
