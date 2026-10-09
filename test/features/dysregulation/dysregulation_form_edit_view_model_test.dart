import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/exceptions/dysregulation_failure.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_management_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';
import 'package:sendaris/features/dysregulation/presentation/viewmodels/dysregulation_form_view_model.dart';

void main() {
  group('DysregulationFormViewModel edición', () {
    test('precarga todos los datos del registro', () {
      final repository = _FakeDysregulationManagementRepository();

      final viewModel = _createViewModel(repository);

      expect(viewModel.isEditing, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 15));

      expect(viewModel.selectedTime, '14:30');

      expect(viewModel.selectedIntensity, DysregulationIntensity.medium);

      expect(viewModel.initialDurationText, '12');

      expect(viewModel.initialContext, 'Actividad cotidiana');

      expect(viewModel.initialObservation, 'Registro inicial.');

      viewModel.dispose();
    });

    test(
      'actualiza el mismo registro conservando identidad y fecha de creación',
      () async {
        final repository = _FakeDysregulationManagementRepository();

        final viewModel = _createViewModel(repository);

        viewModel.setDate(DateTime(2026, 9, 20));

        viewModel.setTime(hour: 18, minute: 45);

        viewModel.setIntensity(DysregulationIntensity.high);

        final success = await viewModel.save(
          durationText: '25',
          context: 'Cambio de actividad',
          observation: 'Registro actualizado.',
        );

        expect(success, isTrue);

        expect(repository.updatedRecords, hasLength(1));

        final updated = repository.updatedRecords.single;

        expect(updated.recordId, 'desregulacion-1');

        expect(updated.anonymousId, 'seguimiento-actual');

        expect(updated.createdAt, DateTime.utc(2026, 9, 15, 20));

        expect(updated.date, DateTime(2026, 9, 20));

        expect(updated.time, '18:45');

        expect(updated.durationMinutes, 25);

        expect(updated.intensity, DysregulationIntensity.high);

        expect(updated.context, 'Cambio de actividad');

        expect(updated.observation, 'Registro actualizado.');

        expect(
          viewModel.successMessage,
          'Registro de desregulación actualizado correctamente.',
        );

        viewModel.dispose();
      },
    );

    test(
      'permite retirar hora duración intensidad contexto y observación',
      () async {
        final repository = _FakeDysregulationManagementRepository();

        final viewModel = _createViewModel(repository);

        viewModel.clearTime();

        viewModel.setIntensity(DysregulationIntensity.medium);

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

        viewModel.dispose();
      },
    );

    test('presenta un error controlado al fallar la actualización', () async {
      final repository = _FakeDysregulationManagementRepository()
        ..updateFailure = const DysregulationFailure(
          'No fue posible actualizar '
          'el registro de desregulación.',
        );

      final viewModel = _createViewModel(repository);

      final success = await viewModel.save(
        durationText: '12',
        context: 'Actividad cotidiana',
        observation: 'Registro inicial.',
      );

      expect(success, isFalse);

      expect(
        viewModel.errorMessage,
        'No fue posible actualizar '
        'el registro de desregulación.',
      );

      expect(repository.updatedRecords, isEmpty);

      viewModel.dispose();
    });
  });
}

DysregulationFormViewModel _createViewModel(
  _FakeDysregulationManagementRepository repository,
) {
  return DysregulationFormViewModel(
    repository,
    const DysregulationRecordFactory(_FakeDysregulationRecordIdGenerator()),
    anonymousId: 'seguimiento-actual',
    initialRecord: _record(),
  );
}

DysregulationRecord _record() {
  return DysregulationRecord(
    recordId: 'desregulacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 15),
    time: '14:30',
    durationMinutes: 12,
    intensity: DysregulationIntensity.medium,
    context: 'Actividad cotidiana',
    observation: 'Registro inicial.',
    createdAt: DateTime.utc(2026, 9, 15, 20),
    updatedAt: DateTime.utc(2026, 9, 15, 20),
  );
}

class _FakeDysregulationManagementRepository
    implements DysregulationManagementRepository {
  final List<DysregulationRecord> savedRecords = [];

  final List<DysregulationRecord> updatedRecords = [];

  DysregulationFailure? updateFailure;

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {
    final failure = updateFailure;

    if (failure != null) {
      throw failure;
    }

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  const _FakeDysregulationRecordIdGenerator();

  @override
  String generate() {
    return 'nuevo-registro';
  }
}
