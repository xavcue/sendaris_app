import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/exceptions/sleep_failure.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_id_generator.dart';
import 'package:sendaris/features/sleep/presentation/viewmodels/sleep_form_view_model.dart';

void main() {
  group('SleepFormViewModel', () {
    late _FakeSleepRepository repository;

    late SleepFormViewModel viewModel;

    setUp(() {
      repository = _FakeSleepRepository();

      viewModel = SleepFormViewModel(
        repository,
        const SleepRecordFactory(_FakeSleepRecordIdGenerator()),
        anonymousId: 'anonimo-1',
        initialDate: DateTime(2026, 9, 9, 18, 45),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('normaliza la fecha inicial sin conservar la hora', () {
      expect(viewModel.selectedDate, DateTime(2026, 9, 9));
    });

    test('calcula duración dentro del mismo día', () {
      viewModel.setStartTime(hour: 20, minute: 30);

      viewModel.setEndTime(hour: 22, minute: 0);

      expect(viewModel.durationMinutes, 90);

      expect(viewModel.formattedDuration, '1 h 30 min');
    });

    test('calcula duración cuando cruza medianoche', () {
      viewModel.setStartTime(hour: 22, minute: 0);

      viewModel.setEndTime(hour: 6, minute: 0);

      expect(viewModel.durationMinutes, 480);

      expect(viewModel.formattedDuration, '8 h');
    });

    test('formatea una duración menor a una hora', () {
      viewModel.setStartTime(hour: 23, minute: 45);

      viewModel.setEndTime(hour: 0, minute: 15);

      expect(viewModel.durationMinutes, 30);

      expect(viewModel.formattedDuration, '30 min');
    });

    test('no calcula duración cuando falta una hora', () {
      viewModel.setStartTime(hour: 22, minute: 0);

      expect(viewModel.durationMinutes, isNull);

      expect(viewModel.formattedDuration, isNull);
    });

    test('exige hora de inicio y hora de finalización', () async {
      final result = await viewModel.save(observation: '');

      expect(result, false);

      expect(viewModel.errorFor('startTime'), 'Selecciona la hora de inicio.');

      expect(
        viewModel.errorFor('endTime'),
        'Selecciona la hora de finalización.',
      );

      expect(repository.savedRecords, isEmpty);
    });

    test('rechaza horas iguales mediante validación de dominio', () async {
      viewModel.setStartTime(hour: 22, minute: 0);

      viewModel.setEndTime(hour: 22, minute: 0);

      final result = await viewModel.save(observation: '');

      expect(result, false);

      expect(viewModel.errorFor('endTime'), isNotNull);

      expect(repository.savedRecords, isEmpty);
    });

    test('guarda un registro válido con duración calculada', () async {
      viewModel.setStartTime(hour: 22, minute: 15);

      viewModel.setEndTime(hour: 6, minute: 45);

      final result = await viewModel.save(observation: 'Registro ficticio.');

      expect(result, true);

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.startTime, '22:15');

      expect(record.endTime, '06:45');

      expect(record.durationMinutes, 510);

      expect(record.observation, 'Registro ficticio.');

      expect(
        viewModel.successMessage,
        'Registro de sueño guardado correctamente.',
      );

      expect(viewModel.startTime, isNull);

      expect(viewModel.endTime, isNull);
    });

    test('presenta un error controlado cuando falla el repositorio', () async {
      repository.failure = const SleepFailure(
        'No fue posible guardar el registro de sueño.',
      );

      viewModel.setStartTime(hour: 22, minute: 0);

      viewModel.setEndTime(hour: 6, minute: 0);

      final result = await viewModel.save(observation: '');

      expect(result, false);

      expect(
        viewModel.errorMessage,
        'No fue posible guardar el registro de sueño.',
      );
    });
  });
}

class _FakeSleepRepository implements SleepRepository {
  final List<SleepRecord> savedRecords = [];

  SleepFailure? failure;

  @override
  Future<void> saveSleep(SleepRecord record) async {
    final currentFailure = failure;

    if (currentFailure != null) {
      throw currentFailure;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeSleepRecordIdGenerator implements SleepRecordIdGenerator {
  const _FakeSleepRecordIdGenerator();

  @override
  String generate() {
    return 'registro-sueno-view-model';
  }
}
