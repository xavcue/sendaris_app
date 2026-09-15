import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/exceptions/dysregulation_failure.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';
import 'package:sendaris/features/dysregulation/presentation/viewmodels/dysregulation_form_view_model.dart';

void main() {
  late _FakeDysregulationRepository repository;
  late DysregulationFormViewModel viewModel;

  setUp(() {
    repository = _FakeDysregulationRepository();

    viewModel = DysregulationFormViewModel(
      repository,
      const DysregulationRecordFactory(_FakeDysregulationRecordIdGenerator()),
      anonymousId: 'anonimo-1',
      initialDate: DateTime(2026, 9, 15, 18, 30),
    );
  });

  test('normaliza la fecha inicial sin componente horario', () {
    expect(viewModel.selectedDate, DateTime(2026, 9, 15));
  });

  test('permite seleccionar y quitar una hora opcional', () {
    viewModel.setTime(hour: 9, minute: 5);

    expect(viewModel.selectedTime, '09:05');

    viewModel.clearTime();

    expect(viewModel.selectedTime, isNull);
  });

  test('la intensidad descriptiva puede seleccionarse y deseleccionarse', () {
    viewModel.setIntensity(DysregulationIntensity.medium);

    expect(viewModel.selectedIntensity, DysregulationIntensity.medium);

    viewModel.setIntensity(DysregulationIntensity.medium);

    expect(viewModel.selectedIntensity, isNull);
  });

  test('guarda un episodio válido con todos los datos opcionales', () async {
    viewModel.setTime(hour: 14, minute: 30);

    viewModel.setIntensity(DysregulationIntensity.medium);

    final success = await viewModel.save(
      durationText: '12',
      context: 'Durante una actividad cotidiana',
      observation: 'Registro ficticio descriptivo.',
    );

    expect(success, isTrue);

    expect(repository.savedRecords, hasLength(1));

    final record = repository.savedRecords.single;

    expect(record.anonymousId, 'anonimo-1');

    expect(record.date, DateTime(2026, 9, 15));

    expect(record.time, '14:30');

    expect(record.durationMinutes, 12);

    expect(record.intensity, DysregulationIntensity.medium);

    expect(record.context, 'Durante una actividad cotidiana');

    expect(record.observation, 'Registro ficticio descriptivo.');
  });

  test('permite guardar sin campos opcionales', () async {
    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, isTrue);

    expect(repository.savedRecords, hasLength(1));

    final record = repository.savedRecords.single;

    expect(record.time, isNull);

    expect(record.durationMinutes, isNull);

    expect(record.intensity, isNull);

    expect(record.context, isNull);

    expect(record.observation, isNull);
  });

  test('permite duración igual a cero', () async {
    final success = await viewModel.save(
      durationText: '0',
      context: '',
      observation: '',
    );

    expect(success, isTrue);

    expect(repository.savedRecords.single.durationMinutes, 0);
  });

  test('rechaza una duración que no sea un número entero', () async {
    final success = await viewModel.save(
      durationText: 'doce',
      context: '',
      observation: '',
    );

    expect(success, isFalse);

    expect(viewModel.errorFor('durationMinutes'), contains('números enteros'));

    expect(repository.savedRecords, isEmpty);
  });

  test('propaga la validación de duración negativa', () async {
    final success = await viewModel.save(
      durationText: '-1',
      context: '',
      observation: '',
    );

    expect(success, isFalse);

    expect(
      viewModel.errorFor('durationMinutes'),
      'La duración no puede ser negativa.',
    );

    expect(repository.savedRecords, isEmpty);
  });

  test(
    'elimina el error de duración cuando el usuario corrige el valor',
    () async {
      final success = await viewModel.save(
        durationText: '-1',
        context: '',
        observation: '',
      );

      expect(success, isFalse);

      expect(
        viewModel.errorFor('durationMinutes'),
        'La duración no puede ser negativa.',
      );

      viewModel.validateDurationCorrection('12');

      expect(viewModel.errorFor('durationMinutes'), isNull);
    },
  );

  test(
    'mantiene actualizado el error mientras la duración siga siendo inválida',
    () async {
      await viewModel.save(durationText: '-1', context: '', observation: '');

      viewModel.validateDurationCorrection('-5');

      expect(
        viewModel.errorFor('durationMinutes'),
        'La duración no puede ser negativa.',
      );

      viewModel.validateDurationCorrection('doce');

      expect(
        viewModel.errorFor('durationMinutes'),
        contains('números enteros'),
      );
    },
  );

  test('presenta un error controlado del repositorio', () async {
    repository.failure = const DysregulationFailure(
      'No tienes autorización para guardar '
      'este episodio de desregulación.',
    );

    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, isFalse);

    expect(viewModel.errorMessage, contains('autorización'));

    expect(repository.savedRecords, isEmpty);
  });

  test('limpia hora e intensidad después de guardar correctamente', () async {
    viewModel.setTime(hour: 16, minute: 45);

    viewModel.setIntensity(DysregulationIntensity.high);

    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, isTrue);

    expect(viewModel.selectedTime, isNull);

    expect(viewModel.selectedIntensity, isNull);
  });

  test('conserva la fecha seleccionada después de guardar', () async {
    viewModel.setDate(DateTime(2026, 9, 14));

    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, isTrue);

    expect(viewModel.selectedDate, DateTime(2026, 9, 14));
  });
}

class _FakeDysregulationRepository implements DysregulationRepository {
  final List<DysregulationRecord> savedRecords = [];

  DysregulationFailure? failure;

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {
    final currentFailure = failure;

    if (currentFailure != null) {
      throw currentFailure;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    return const [];
  }
}

class _FakeDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  const _FakeDysregulationRecordIdGenerator();

  @override
  String generate() {
    return 'desregulacion-1';
  }
}
