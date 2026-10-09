import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/atypical_situation/presentation/viewmodels/atypical_situation_form_view_model.dart';

void main() {
  group('AtypicalSituationFormViewModel', () {
    late _FakeAtypicalSituationRepository repository;

    setUp(() {
      repository = _FakeAtypicalSituationRepository();
    });

    test('normaliza la fecha inicial y comienza sin categoría', () {
      final viewModel = _createViewModel(
        repository,
        initialDate: DateTime(2026, 9, 7, 23, 45),
      );

      expect(viewModel.selectedDate, DateTime(2026, 9, 7));

      expect(viewModel.selectedCategory, isNull);

      expect(viewModel.isSaving, isFalse);

      viewModel.dispose();
    });

    test('sin fecha inicial comienza sin fecha seleccionada', () {
      final viewModel = _createViewModel(repository);

      expect(viewModel.selectedDate, isNull);

      viewModel.dispose();
    });

    test('permite seleccionar una fecha', () {
      final viewModel = _createViewModel(repository);

      viewModel.selectDate(DateTime(2026, 9, 21, 18, 30));

      expect(viewModel.selectedDate, DateTime(2026, 9, 21));

      viewModel.dispose();
    });

    test('permite seleccionar y deseleccionar una categoría', () {
      final viewModel = _createViewModel(repository);

      viewModel.selectCategory(AtypicalSituationCategory.environmentChange);

      expect(
        viewModel.selectedCategory,
        AtypicalSituationCategory.environmentChange,
      );

      viewModel.selectCategory(AtypicalSituationCategory.environmentChange);

      expect(viewModel.selectedCategory, isNull);

      viewModel.dispose();
    });

    test('rechaza guardado sin fecha categoría ni descripción', () async {
      final viewModel = _createViewModel(repository);

      final result = await viewModel.save(observation: '   ');

      expect(result, isFalse);

      expect(viewModel.errorFor('date'), 'Selecciona una fecha.');

      expect(
        viewModel.errorFor('category'),
        'Selecciona una categoría para continuar.',
      );

      expect(
        viewModel.errorFor('observation'),
        'Describe brevemente lo ocurrido.',
      );

      expect(repository.savedRecords, isEmpty);

      viewModel.dispose();
    });

    test('seleccionar la fecha elimina su error', () async {
      final viewModel = _createViewModel(repository);

      await viewModel.save(observation: '');

      expect(viewModel.errorFor('date'), isNotNull);

      viewModel.selectDate(DateTime(2026, 9, 21));

      expect(viewModel.errorFor('date'), isNull);

      viewModel.dispose();
    });

    test('seleccionar una categoría elimina su error', () async {
      final viewModel = _createViewModel(repository);

      await viewModel.save(observation: '');

      expect(viewModel.errorFor('category'), isNotNull);

      viewModel.selectCategory(AtypicalSituationCategory.unexpectedEvent);

      expect(viewModel.errorFor('category'), isNull);

      viewModel.dispose();
    });

    test('guarda una situación válida y normaliza la descripción', () async {
      final viewModel = _createViewModel(
        repository,
        initialDate: DateTime(2026, 9, 21),
      );

      viewModel.selectCategory(AtypicalSituationCategory.unexpectedEvent);

      final result = await viewModel.save(
        observation: '  La actividad prevista fue suspendida.  ',
      );

      expect(result, isTrue);

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.anonymousId, 'anonimo-test');

      expect(record.date, DateTime(2026, 9, 21));

      expect(record.category, AtypicalSituationCategory.unexpectedEvent);

      expect(record.observation, 'La actividad prevista fue suspendida.');

      expect(viewModel.selectedDate, isNull);

      expect(viewModel.selectedCategory, isNull);

      viewModel.dispose();
    });
  });
}

AtypicalSituationFormViewModel _createViewModel(
  _FakeAtypicalSituationRepository repository, {
  DateTime? initialDate,
}) {
  return AtypicalSituationFormViewModel(
    repository,
    const AtypicalSituationRecordFactory(_FakeRecordIdGenerator()),
    anonymousId: 'anonimo-test',
    initialDate: initialDate,
  );
}

class _FakeAtypicalSituationRepository implements AtypicalSituationRepository {
  final List<AtypicalSituationRecord> savedRecords = [];

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    savedRecords.add(record);
  }

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
    return 'situacion-form-test';
  }
}
