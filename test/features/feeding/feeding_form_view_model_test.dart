import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/exceptions/feeding_failure.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_id_generator.dart';
import 'package:sendaris/features/feeding/presentation/viewmodels/feeding_form_view_model.dart';

void main() {
  group('FeedingFormViewModel', () {
    late _FakeFeedingRepository repository;

    late FeedingFormViewModel viewModel;

    setUp(() {
      repository = _FakeFeedingRepository();

      viewModel = FeedingFormViewModel(
        repository,
        const FeedingRecordFactory(_FakeFeedingRecordIdGenerator()),
        anonymousId: 'anonimo-1',
        initialDate: DateTime(2026, 9, 10, 18, 45),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('normaliza la fecha inicial sin conservar la hora', () {
      expect(viewModel.selectedDate, DateTime(2026, 9, 10));
    });

    test('inicia sin una categoría seleccionada', () {
      expect(viewModel.selectedCategory, isNull);
    });

    test('permite seleccionar una categoría general', () {
      viewModel.setCategory(FeedingCategory.lunch);

      expect(viewModel.selectedCategory, FeedingCategory.lunch);
    });

    test('permite actualizar la fecha', () {
      viewModel.setDate(DateTime(2026, 9, 11, 23, 30));

      expect(viewModel.selectedDate, DateTime(2026, 9, 11));
    });

    test('exige seleccionar una categoría antes de guardar', () async {
      final result = await viewModel.save(observation: '');

      expect(result, false);

      expect(
        viewModel.errorFor('category'),
        'Selecciona una categoría de alimentación.',
      );

      expect(repository.savedRecords, isEmpty);
    });

    test('guarda un registro válido con observación descriptiva', () async {
      viewModel.setCategory(FeedingCategory.lunch);

      final result = await viewModel.save(
        observation: 'Registro ficticio descriptivo.',
      );

      expect(result, true);

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.anonymousId, 'anonimo-1');

      expect(record.date, DateTime(2026, 9, 10));

      expect(record.category, FeedingCategory.lunch);

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(
        viewModel.successMessage,
        'Registro de alimentación guardado correctamente.',
      );

      expect(viewModel.selectedCategory, isNull);
    });

    test('permite guardar sin observación', () async {
      viewModel.setCategory(FeedingCategory.breakfast);

      final result = await viewModel.save(observation: '');

      expect(result, true);

      expect(repository.savedRecords, hasLength(1));

      expect(repository.savedRecords.single.observation, isNull);
    });

    test(
      'elimina el error de categoría al seleccionar una opción válida',
      () async {
        await viewModel.save(observation: '');

        expect(viewModel.errorFor('category'), isNotNull);

        viewModel.setCategory(FeedingCategory.snack);

        expect(viewModel.errorFor('category'), isNull);
      },
    );

    test('presenta un error controlado cuando falla el repositorio', () async {
      repository.failure = const FeedingFailure(
        'No fue posible guardar el registro de alimentación.',
      );

      viewModel.setCategory(FeedingCategory.other);

      final result = await viewModel.save(observation: '');

      expect(result, false);

      expect(
        viewModel.errorMessage,
        'No fue posible guardar el registro de alimentación.',
      );

      expect(viewModel.selectedCategory, FeedingCategory.other);
    });

    test('presenta un mensaje controlado ante un error inesperado', () async {
      repository.unexpectedError = Exception('Error interno');

      viewModel.setCategory(FeedingCategory.afternoonMealOrDinner);

      final result = await viewModel.save(observation: '');

      expect(result, false);

      expect(
        viewModel.errorMessage,
        'No fue posible guardar el registro de alimentación. '
        'Inténtalo nuevamente.',
      );
    });
  });
}

class _FakeFeedingRepository implements FeedingRepository {
  final List<FeedingRecord> savedRecords = [];

  FeedingFailure? failure;

  Object? unexpectedError;

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    final currentFailure = failure;

    if (currentFailure != null) {
      throw currentFailure;
    }

    final currentUnexpectedError = unexpectedError;

    if (currentUnexpectedError != null) {
      throw currentUnexpectedError;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  const _FakeFeedingRecordIdGenerator();

  @override
  String generate() {
    return 'registro-alimentacion-view-model';
  }
}
