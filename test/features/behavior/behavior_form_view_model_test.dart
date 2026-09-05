import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/exceptions/behavior_failure.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
import 'package:sendaris/features/behavior/presentation/viewmodels/behavior_form_view_model.dart';

void main() {
  late _FakeBehaviorRepository repository;
  late BehaviorFormViewModel viewModel;

  setUp(() {
    repository = _FakeBehaviorRepository();

    viewModel = BehaviorFormViewModel(
      repository,
      const BehaviorRecordFactory(_FakeBehaviorRecordIdGenerator()),
      anonymousId: 'anonimo-1',
      initialDate: DateTime(2026, 9, 5),
    );
  });

  test('guarda una conducta válida con los datos seleccionados', () async {
    viewModel.setCategory(BehaviorCategory.repetitiveBehavior);

    viewModel.setTime(hour: 14, minute: 30);

    viewModel.setIntensity(BehaviorIntensity.medium);

    final success = await viewModel.save(
      durationText: '12',
      context: 'Actividad cotidiana',
      observation: 'Registro ficticio.',
    );

    expect(success, true);
    expect(repository.savedRecords.length, 1);

    final record = repository.savedRecords.single;

    expect(record.anonymousId, 'anonimo-1');

    expect(record.category, BehaviorCategory.repetitiveBehavior);

    expect(record.time, '14:30');
    expect(record.durationMinutes, 12);

    expect(record.intensity, BehaviorIntensity.medium);
  });

  test('requiere seleccionar una categoría', () async {
    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, false);

    expect(viewModel.errorFor('category'), isNotNull);

    expect(repository.savedRecords, isEmpty);
  });

  test('rechaza una duración no numérica', () async {
    viewModel.setCategory(BehaviorCategory.socialInitiative);

    final success = await viewModel.save(
      durationText: 'doce',
      context: '',
      observation: '',
    );

    expect(success, false);

    expect(viewModel.errorFor('durationMinutes'), contains('números'));
  });

  test('propaga la validación de duración mayor que cero', () async {
    viewModel.setCategory(BehaviorCategory.avoidanceFear);

    final success = await viewModel.save(
      durationText: '0',
      context: '',
      observation: '',
    );

    expect(success, false);

    expect(viewModel.errorFor('durationMinutes'), isNotNull);
  });

  test('presenta un error controlado del repositorio', () async {
    viewModel.setCategory(BehaviorCategory.repetitiveBehavior);

    repository.failure = const BehaviorFailure(
      'No tienes autorización para '
      'guardar esta conducta.',
    );

    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, false);

    expect(viewModel.errorMessage, contains('autorización'));
  });

  test('limpia selecciones transitorias después de guardar', () async {
    viewModel.setCategory(BehaviorCategory.aggressionIrritability);

    viewModel.setTime(hour: 9, minute: 5);

    viewModel.setIntensity(BehaviorIntensity.high);

    final success = await viewModel.save(
      durationText: '',
      context: '',
      observation: '',
    );

    expect(success, true);
    expect(viewModel.selectedCategory, isNull);
    expect(viewModel.selectedTime, isNull);
    expect(viewModel.selectedIntensity, isNull);
  });
}

class _FakeBehaviorRepository implements BehaviorRepository {
  final List<BehaviorRecord> savedRecords = [];

  BehaviorFailure? failure;

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    final currentFailure = failure;

    if (currentFailure != null) {
      throw currentFailure;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return const [];
  }
}

class _FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const _FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'registro-1';
  }
}
