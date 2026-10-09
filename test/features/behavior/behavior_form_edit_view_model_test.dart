import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/exceptions/behavior_failure.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
import 'package:sendaris/features/behavior/presentation/viewmodels/behavior_form_view_model.dart';

void main() {
  group('BehaviorFormViewModel edición', () {
    late _FakeBehaviorManagementRepository repository;

    late BehaviorRecord initialRecord;

    late BehaviorFormViewModel viewModel;

    setUp(() {
      repository = _FakeBehaviorManagementRepository();

      initialRecord = BehaviorRecord(
        recordId: 'conducta-existente',
        anonymousId: 'seguimiento-actual',
        date: DateTime(2026, 9, 20),
        time: '08:30',
        category: BehaviorCategory.avoidanceFear,
        durationMinutes: 15,
        intensity: BehaviorIntensity.low,
        context: 'Antes de una transición',
        observation: 'Registro inicial.',
        createdAt: DateTime.utc(2026, 9, 20, 13, 30),
        updatedAt: DateTime.utc(2026, 9, 20, 13, 30),
      );

      viewModel = BehaviorFormViewModel(
        repository,
        const BehaviorRecordFactory(_FakeBehaviorRecordIdGenerator()),
        anonymousId: 'seguimiento-actual',
        initialRecord: initialRecord,
      );
    });

    test('precarga los valores del registro existente', () {
      expect(viewModel.isEditing, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 20));

      expect(viewModel.selectedTime, '08:30');

      expect(viewModel.selectedCategory, BehaviorCategory.avoidanceFear);

      expect(viewModel.selectedIntensity, BehaviorIntensity.low);

      expect(viewModel.initialDurationText, '15');

      expect(viewModel.initialContext, 'Antes de una transición');

      expect(viewModel.initialObservation, 'Registro inicial.');
    });

    test(
      'actualiza la conducta conservando identidad y fecha de creación',
      () async {
        viewModel.setDate(DateTime(2026, 9, 22));

        viewModel.setTime(hour: 19, minute: 45);

        viewModel.setCategory(BehaviorCategory.repetitiveBehavior);

        viewModel.setIntensity(BehaviorIntensity.medium);

        final success = await viewModel.save(
          durationText: '10',
          context: 'Cambio de actividad',
          observation: 'Registro actualizado.',
        );

        expect(success, isTrue);

        expect(repository.savedRecords, isEmpty);

        expect(repository.updatedRecords.length, 1);

        final updated = repository.updatedRecords.single;

        expect(updated.recordId, initialRecord.recordId);

        expect(updated.anonymousId, initialRecord.anonymousId);

        expect(updated.createdAt, initialRecord.createdAt);

        expect(updated.date, DateTime(2026, 9, 22));

        expect(updated.time, '19:45');

        expect(updated.category, BehaviorCategory.repetitiveBehavior);

        expect(updated.durationMinutes, 10);

        expect(updated.intensity, BehaviorIntensity.medium);

        expect(updated.context, 'Cambio de actividad');

        expect(updated.observation, 'Registro actualizado.');

        expect(updated.updatedAt.isAfter(initialRecord.updatedAt), isTrue);

        expect(viewModel.successMessage, 'Conducta actualizada correctamente.');
      },
    );

    test('permite retirar todos los campos opcionales al editar', () async {
      viewModel.clearTime();

      viewModel.setIntensity(BehaviorIntensity.low);

      final success = await viewModel.save(
        durationText: '',
        context: '',
        observation: '',
      );

      expect(success, isTrue);

      final updated = repository.updatedRecords.single;

      expect(updated.time, isNull);

      expect(updated.durationMinutes, isNull);

      expect(updated.intensity, isNull);

      expect(updated.context, isNull);

      expect(updated.observation, isNull);
    });

    test(
      'presenta el error controlado cuando la actualización falla',
      () async {
        repository.updateFailure = const BehaviorFailure(
          'No fue posible actualizar esta conducta.',
        );

        final success = await viewModel.save(
          durationText: '15',
          context: 'Antes de una transición',
          observation: 'Registro inicial.',
        );

        expect(success, isFalse);

        expect(
          viewModel.errorMessage,
          'No fue posible actualizar esta conducta.',
        );

        expect(repository.updatedRecords, isEmpty);
      },
    );
  });
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  final List<BehaviorRecord> savedRecords = [];

  final List<BehaviorRecord> updatedRecords = [];

  BehaviorFailure? updateFailure;

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {
    final failure = updateFailure;

    if (failure != null) {
      throw failure;
    }

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const _FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'registro-nuevo';
  }
}
