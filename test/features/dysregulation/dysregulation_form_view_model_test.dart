import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/exceptions/dysregulation_failure.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';
import 'package:sendaris/features/dysregulation/presentation/viewmodels/dysregulation_form_view_model.dart';

void main() {
  group('DysregulationFormViewModel', () {
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

    tearDown(() {
      viewModel.dispose();
    });

    test('normaliza la fecha inicial sin componente horario', () {
      expect(viewModel.selectedDate, DateTime(2026, 9, 15));
    });

    test('sin fecha inicial comienza sin fecha seleccionada', () {
      final freshViewModel = DysregulationFormViewModel(
        repository,
        const DysregulationRecordFactory(_FakeDysregulationRecordIdGenerator()),
        anonymousId: 'anonimo-2',
      );

      expect(freshViewModel.selectedDate, isNull);

      freshViewModel.dispose();
    });

    test('permite seleccionar una fecha', () {
      viewModel.setDate(DateTime(2026, 9, 21, 23, 45));

      expect(viewModel.selectedDate, DateTime(2026, 9, 21));
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

    test('exige seleccionar una fecha antes de guardar', () async {
      final freshViewModel = DysregulationFormViewModel(
        repository,
        const DysregulationRecordFactory(_FakeDysregulationRecordIdGenerator()),
        anonymousId: 'anonimo-2',
      );

      final success = await freshViewModel.save(
        durationText: '',
        context: '',
        observation: '',
      );

      expect(success, isFalse);

      expect(freshViewModel.errorFor('date'), 'Selecciona una fecha.');

      expect(repository.savedRecords, isEmpty);

      freshViewModel.dispose();
    });

    test('elimina el error de fecha al seleccionar una fecha válida', () async {
      final freshViewModel = DysregulationFormViewModel(
        repository,
        const DysregulationRecordFactory(_FakeDysregulationRecordIdGenerator()),
        anonymousId: 'anonimo-2',
      );

      await freshViewModel.save(durationText: '', context: '', observation: '');

      expect(freshViewModel.errorFor('date'), isNotNull);

      freshViewModel.setDate(DateTime(2026, 9, 21));

      expect(freshViewModel.errorFor('date'), isNull);

      freshViewModel.dispose();
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

      expect(
        viewModel.successMessage,
        'Episodio de desregulación guardado correctamente.',
      );

      expect(viewModel.selectedDate, isNull);

      expect(viewModel.selectedTime, isNull);

      expect(viewModel.selectedIntensity, isNull);
    });

    test('permite guardar solo con la fecha', () async {
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

      expect(
        viewModel.errorFor('durationMinutes'),
        contains('números enteros'),
      );

      expect(repository.savedRecords, isEmpty);
    });

    test('rechaza una duración negativa', () async {
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
        await viewModel.save(durationText: '-1', context: '', observation: '');

        expect(viewModel.errorFor('durationMinutes'), isNotNull);

        viewModel.validateDurationCorrection('12');

        expect(viewModel.errorFor('durationMinutes'), isNull);
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
