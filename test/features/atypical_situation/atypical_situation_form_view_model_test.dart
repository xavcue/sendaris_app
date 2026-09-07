import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/atypical_situation/presentation/viewmodels/atypical_situation_form_view_model.dart';

void main() {
  group('AtypicalSituationFormViewModel', () {
    test('inicia con la fecha normalizada y sin categoría', () {
      final repository = _FakeAtypicalSituationRepository();

      const factory = AtypicalSituationRecordFactory(_FakeRecordIdGenerator());

      final viewModel = AtypicalSituationFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
        initialDate: DateTime(2026, 9, 7, 23, 45),
      );

      expect(viewModel.selectedDate, DateTime(2026, 9, 7));

      expect(viewModel.selectedCategory, isNull);

      expect(viewModel.isSaving, isFalse);
    });

    test('permite seleccionar fecha y categoría', () {
      final repository = _FakeAtypicalSituationRepository();

      const factory = AtypicalSituationRecordFactory(_FakeRecordIdGenerator());

      final viewModel = AtypicalSituationFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
      );

      viewModel.selectDate(DateTime(2026, 9, 5, 18, 30));

      viewModel.selectCategory(AtypicalSituationCategory.environmentChange);

      expect(viewModel.selectedDate, DateTime(2026, 9, 5));

      expect(
        viewModel.selectedCategory,
        AtypicalSituationCategory.environmentChange,
      );
    });

    test('rechaza guardado sin categoría ni descripción', () async {
      final repository = _FakeAtypicalSituationRepository();

      const factory = AtypicalSituationRecordFactory(_FakeRecordIdGenerator());

      final viewModel = AtypicalSituationFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
      );

      final result = await viewModel.save(observation: '   ');

      expect(result, isFalse);

      expect(viewModel.errorFor('category'), isNotNull);

      expect(viewModel.errorFor('observation'), isNotNull);

      expect(repository.savedRecord, isNull);
    });

    test('guarda una situación válida', () async {
      final repository = _FakeAtypicalSituationRepository();

      const factory = AtypicalSituationRecordFactory(_FakeRecordIdGenerator());

      final viewModel = AtypicalSituationFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
        initialDate: DateTime(2026, 9, 6),
      );

      viewModel.selectCategory(AtypicalSituationCategory.unexpectedEvent);

      final result = await viewModel.save(
        observation: '  La actividad prevista fue suspendida.  ',
      );

      expect(result, isTrue);

      expect(repository.savedRecord, isNotNull);

      expect(repository.savedRecord!.anonymousId, 'anonimo-test');

      expect(
        repository.savedRecord!.category,
        AtypicalSituationCategory.unexpectedEvent,
      );

      expect(
        repository.savedRecord!.observation,
        'La actividad prevista fue suspendida.',
      );

      expect(repository.savedRecord!.date, DateTime(2026, 9, 6));
    });
  });
}

class _FakeAtypicalSituationRepository implements AtypicalSituationRepository {
  AtypicalSituationRecord? savedRecord;

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    savedRecord = record;
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
