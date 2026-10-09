import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/exceptions/feeding_failure.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_management_repository.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_id_generator.dart';
import 'package:sendaris/features/feeding/presentation/viewmodels/feeding_form_view_model.dart';

void main() {
  group('FeedingFormViewModel edición', () {
    late _FakeFeedingManagementRepository repository;
    late FeedingRecord initialRecord;
    late FeedingFormViewModel viewModel;

    setUp(() {
      repository = _FakeFeedingManagementRepository();

      initialRecord = _record();

      viewModel = FeedingFormViewModel(
        repository,
        const FeedingRecordFactory(_FakeFeedingRecordIdGenerator()),
        anonymousId: 'seguimiento-actual',
        initialRecord: initialRecord,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('precarga fecha categoría y observación del registro existente', () {
      expect(viewModel.isEditing, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 22));

      expect(viewModel.selectedCategory, FeedingCategory.lunch);

      expect(viewModel.initialObservation, 'Registro ficticio.');
    });

    test(
      'actualiza el mismo registro preservando identidad y fecha de creación',
      () async {
        viewModel.setDate(DateTime(2026, 9, 23));

        viewModel.setCategory(FeedingCategory.breakfast);

        final success = await viewModel.save(
          observation: 'Observación actualizada.',
        );

        expect(success, isTrue);

        expect(repository.savedRecords, isEmpty);

        expect(repository.updatedRecords, hasLength(1));

        final updatedRecord = repository.updatedRecords.single;

        expect(updatedRecord.recordId, initialRecord.recordId);

        expect(updatedRecord.anonymousId, initialRecord.anonymousId);

        expect(updatedRecord.createdAt, initialRecord.createdAt);

        expect(updatedRecord.date, DateTime(2026, 9, 23));

        expect(updatedRecord.category, FeedingCategory.breakfast);

        expect(updatedRecord.observation, 'Observación actualizada.');

        expect(
          updatedRecord.updatedAt.isAfter(initialRecord.updatedAt),
          isTrue,
        );

        expect(
          viewModel.successMessage,
          'Registro de alimentación actualizado correctamente.',
        );
      },
    );

    test(
      'permite eliminar la observación opcional durante la edición',
      () async {
        final success = await viewModel.save(observation: '   ');

        expect(success, isTrue);

        expect(repository.updatedRecords, hasLength(1));

        expect(repository.updatedRecords.single.observation, isNull);
      },
    );

    test(
      'mantiene el registro precargado cuando falla la actualización',
      () async {
        repository.updateFailure = const FeedingFailure(
          'No fue posible actualizar '
          'el registro de alimentación.',
        );

        viewModel.setCategory(FeedingCategory.snack);

        final success = await viewModel.save(observation: 'Registro editado.');

        expect(success, isFalse);

        expect(repository.updatedRecords, isEmpty);

        expect(
          viewModel.errorMessage,
          'No fue posible actualizar '
          'el registro de alimentación.',
        );

        expect(viewModel.selectedDate, DateTime(2026, 9, 22));

        expect(viewModel.selectedCategory, FeedingCategory.snack);
      },
    );
  });
}

FeedingRecord _record() {
  return FeedingRecord(
    recordId: 'alimentacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: FeedingCategory.lunch,
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeFeedingManagementRepository implements FeedingManagementRepository {
  final List<FeedingRecord> savedRecords = [];
  final List<FeedingRecord> updatedRecords = [];

  FeedingFailure? updateFailure;

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateFeeding(FeedingRecord record) async {
    final failure = updateFailure;

    if (failure != null) {
      throw failure;
    }

    updatedRecords.add(record);
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return [];
  }

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  const _FakeFeedingRecordIdGenerator();

  @override
  String generate() {
    return 'nuevo-id-no-utilizado-en-edicion';
  }
}
