import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/exceptions/atypical_situation_failure.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_management_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/atypical_situation/presentation/viewmodels/atypical_situation_form_view_model.dart';

void main() {
  group('AtypicalSituationFormViewModel edición', () {
    late _FakeAtypicalSituationManagementRepository repository;
    late AtypicalSituationRecord initialRecord;
    late AtypicalSituationFormViewModel viewModel;

    setUp(() {
      repository = _FakeAtypicalSituationManagementRepository();

      initialRecord = _record();

      viewModel = AtypicalSituationFormViewModel(
        repository,
        const AtypicalSituationRecordFactory(_FakeRecordIdGenerator()),
        anonymousId: 'seguimiento-actual',
        initialRecord: initialRecord,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('precarga fecha categoría y descripción', () {
      expect(viewModel.isEditing, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 22));

      expect(
        viewModel.selectedCategory,
        AtypicalSituationCategory.unexpectedEvent,
      );

      expect(
        viewModel.initialObservation,
        'Se suspendió una actividad programada.',
      );
    });

    test(
      'actualiza el mismo registro preservando identidad y creación',
      () async {
        viewModel.selectDate(DateTime(2026, 9, 23));

        viewModel.selectCategory(AtypicalSituationCategory.scheduleChange);

        final success = await viewModel.save(
          observation: '  Se modificó el horario previsto.  ',
        );

        expect(success, isTrue);

        expect(repository.savedRecords, isEmpty);

        expect(repository.updatedRecords, hasLength(1));

        final updatedRecord = repository.updatedRecords.single;

        expect(updatedRecord.recordId, initialRecord.recordId);

        expect(updatedRecord.anonymousId, initialRecord.anonymousId);

        expect(updatedRecord.createdAt, initialRecord.createdAt);

        expect(updatedRecord.date, DateTime(2026, 9, 23));

        expect(
          updatedRecord.category,
          AtypicalSituationCategory.scheduleChange,
        );

        expect(updatedRecord.observation, 'Se modificó el horario previsto.');

        expect(
          updatedRecord.updatedAt.isAfter(initialRecord.updatedAt),
          isTrue,
        );

        expect(
          viewModel.successMessage,
          'Registro de otra situación '
          'actualizado correctamente.',
        );
      },
    );

    test('mantiene obligatoria la descripción durante la edición', () async {
      final success = await viewModel.save(observation: '   ');

      expect(success, isFalse);

      expect(
        viewModel.errorFor('observation'),
        'Describe brevemente lo ocurrido.',
      );

      expect(repository.updatedRecords, isEmpty);
    });

    test('expone de forma controlada un fallo de actualización', () async {
      repository.updateFailure = const AtypicalSituationFailure(
        'No fue posible actualizar la situación.',
      );

      viewModel.selectCategory(AtypicalSituationCategory.externalInterruption);

      final success = await viewModel.save(
        observation: 'Se interrumpió temporalmente la actividad.',
      );

      expect(success, isFalse);

      expect(repository.updatedRecords, isEmpty);

      expect(viewModel.errorMessage, 'No fue posible actualizar la situación.');

      expect(viewModel.selectedDate, initialRecord.date);

      expect(
        viewModel.selectedCategory,
        AtypicalSituationCategory.externalInterruption,
      );

      expect(viewModel.initialObservation, initialRecord.observation);
    });
  });
}

AtypicalSituationRecord _record() {
  return AtypicalSituationRecord(
    recordId: 'situacion-existente',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: AtypicalSituationCategory.unexpectedEvent,
    observation: 'Se suspendió una actividad programada.',
    createdAt: DateTime.utc(2026, 9, 22, 12),
    updatedAt: DateTime.utc(2026, 9, 22, 12),
  );
}

class _FakeAtypicalSituationManagementRepository
    implements AtypicalSituationManagementRepository {
  final List<AtypicalSituationRecord> savedRecords = [];
  final List<AtypicalSituationRecord> updatedRecords = [];

  Object? updateFailure;

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {
    final failure = updateFailure;

    if (failure != null) {
      throw failure;
    }

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {}

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeRecordIdGenerator implements AtypicalSituationRecordIdGenerator {
  const _FakeRecordIdGenerator();

  @override
  String generate() {
    return 'situacion-edit-test';
  }
}
