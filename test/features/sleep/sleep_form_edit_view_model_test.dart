import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/exceptions/sleep_failure.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_management_repository.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_id_generator.dart';
import 'package:sendaris/features/sleep/presentation/viewmodels/sleep_form_view_model.dart';

void main() {
  group('SleepFormViewModel edición', () {
    late _FakeSleepManagementRepository repository;

    late SleepRecord initialRecord;

    late SleepFormViewModel viewModel;

    setUp(() {
      repository = _FakeSleepManagementRepository();

      initialRecord = SleepRecord(
        recordId: 'sueno-existente',
        anonymousId: 'seguimiento-1',
        date: DateTime(2026, 9, 20),
        startTime: '22:00',
        endTime: '06:00',
        durationMinutes: 480,
        observation: 'Observación inicial.',
        createdAt: DateTime.utc(2026, 9, 21, 8),
        updatedAt: DateTime.utc(2026, 9, 21, 8),
      );

      viewModel = SleepFormViewModel(
        repository,
        const SleepRecordFactory(_FakeSleepRecordIdGenerator()),
        anonymousId: 'seguimiento-1',
        initialRecord: initialRecord,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('inicializa el formulario con los datos existentes', () {
      expect(viewModel.isEditing, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 20));

      expect(viewModel.startTime, '22:00');

      expect(viewModel.endTime, '06:00');

      expect(viewModel.formattedDuration, '8 h');

      expect(viewModel.initialObservation, 'Observación inicial.');
    });

    test('actualiza el mismo registro sin crear uno nuevo', () async {
      viewModel.setDate(DateTime(2026, 9, 22));

      viewModel.setStartTime(hour: 23, minute: 0);

      viewModel.setEndTime(hour: 7, minute: 30);

      final success = await viewModel.save(
        observation: 'Observación actualizada.',
      );

      expect(success, isTrue);

      expect(repository.savedRecords, isEmpty);

      expect(repository.updatedRecords, hasLength(1));

      final updated = repository.updatedRecords.single;

      expect(updated.recordId, initialRecord.recordId);

      expect(updated.anonymousId, initialRecord.anonymousId);

      expect(updated.createdAt, initialRecord.createdAt);

      expect(updated.date, DateTime(2026, 9, 22));

      expect(updated.startTime, '23:00');

      expect(updated.endTime, '07:30');

      expect(updated.durationMinutes, 510);

      expect(updated.observation, 'Observación actualizada.');

      expect(
        viewModel.successMessage,
        'Registro de sueño actualizado correctamente.',
      );
    });

    test('después de actualizar conserva los valores del formulario', () async {
      viewModel.setStartTime(hour: 21, minute: 30);

      viewModel.setEndTime(hour: 5, minute: 30);

      final success = await viewModel.save(observation: '');

      expect(success, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 20));

      expect(viewModel.startTime, '21:30');

      expect(viewModel.endTime, '05:30');

      expect(viewModel.formattedDuration, '8 h');
    });

    test(
      'presenta un error controlado cuando falla la actualización',
      () async {
        repository.updateFailure = const SleepFailure(
          'No fue posible actualizar el registro de sueño.',
        );

        final success = await viewModel.save(observation: 'Observación.');

        expect(success, isFalse);

        expect(repository.updatedRecords, isEmpty);

        expect(
          viewModel.errorMessage,
          'No fue posible actualizar el registro de sueño.',
        );

        expect(viewModel.isSaving, isFalse);
      },
    );
  });
}

class _FakeSleepManagementRepository implements SleepManagementRepository {
  final List<SleepRecord> savedRecords = [];

  final List<SleepRecord> updatedRecords = [];

  SleepFailure? updateFailure;

  @override
  Future<void> saveSleep(SleepRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateSleep(SleepRecord record) async {
    final failure = updateFailure;

    if (failure != null) {
      throw failure;
    }

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeSleepRecordIdGenerator implements SleepRecordIdGenerator {
  const _FakeSleepRecordIdGenerator();

  @override
  String generate() {
    return 'nuevo-id-no-utilizado';
  }
}
