import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/exceptions/social_interaction_failure.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_management_repository.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_id_generator.dart';
import 'package:sendaris/features/social_interaction/presentation/viewmodels/social_interaction_form_view_model.dart';

void main() {
  group('SocialInteractionFormViewModel edición', () {
    late _FakeSocialInteractionManagementRepository repository;

    late SocialInteractionFormViewModel viewModel;

    setUp(() {
      repository = _FakeSocialInteractionManagementRepository();

      viewModel = SocialInteractionFormViewModel(
        repository,
        const SocialInteractionRecordFactory(
          _FakeSocialInteractionRecordIdGenerator(),
        ),
        anonymousId: 'seguimiento-actual',
        initialRecord: _record(),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('precarga los datos del registro', () {
      expect(viewModel.isEditing, isTrue);

      expect(viewModel.selectedDate, DateTime(2026, 9, 22));

      expect(
        viewModel.selectedCategory,
        SocialInteractionCategory.socialExchange,
      );

      expect(viewModel.initialContext, 'Actividad recreativa');

      expect(viewModel.initialObservation, 'Registro ficticio.');
    });

    test(
      'actualiza el mismo registro conservando sus identificadores',
      () async {
        viewModel.setDate(DateTime(2026, 9, 23, 20));

        viewModel.setCategory(SocialInteractionCategory.sharedActivity);

        final success = await viewModel.save(
          context: '  Actividad grupal  ',
          observation: '  Observación actualizada.  ',
        );

        expect(success, isTrue);

        expect(repository.updatedRecords, hasLength(1));

        final updated = repository.updatedRecords.single;

        expect(updated.recordId, 'interaccion-1');

        expect(updated.anonymousId, 'seguimiento-actual');

        expect(updated.createdAt, DateTime.utc(2026, 9, 22, 18));

        expect(updated.date, DateTime(2026, 9, 23));

        expect(updated.category, SocialInteractionCategory.sharedActivity);

        expect(updated.context, 'Actividad grupal');

        expect(updated.observation, 'Observación actualizada.');

        expect(
          viewModel.successMessage,
          'Registro de interacción social actualizado correctamente.',
        );
      },
    );

    test('permite retirar contexto y observación opcionales', () async {
      final success = await viewModel.save(context: '', observation: '');

      expect(success, isTrue);

      expect(repository.updatedRecords, hasLength(1));

      expect(repository.updatedRecords.single.context, isNull);

      expect(repository.updatedRecords.single.observation, isNull);
    });

    test('presenta un error controlado si falla la actualización', () async {
      repository.updateFailure = const SocialInteractionFailure(
        'No fue posible actualizar '
        'el registro de interacción social.',
      );

      final success = await viewModel.save(
        context: 'Actividad recreativa',
        observation: 'Registro ficticio.',
      );

      expect(success, isFalse);

      expect(repository.updatedRecords, isEmpty);

      expect(
        viewModel.errorMessage,
        'No fue posible actualizar '
        'el registro de interacción social.',
      );

      expect(viewModel.selectedDate, DateTime(2026, 9, 22));

      expect(
        viewModel.selectedCategory,
        SocialInteractionCategory.socialExchange,
      );
    });
  });
}

SocialInteractionRecord _record() {
  return SocialInteractionRecord(
    recordId: 'interaccion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: SocialInteractionCategory.socialExchange,
    context: 'Actividad recreativa',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeSocialInteractionManagementRepository
    implements SocialInteractionManagementRepository {
  final List<SocialInteractionRecord> savedRecords = [];

  final List<SocialInteractionRecord> updatedRecords = [];

  SocialInteractionFailure? updateFailure;

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return [];
  }

  @override
  Future<void> updateSocialInteraction(SocialInteractionRecord record) async {
    final failure = updateFailure;

    if (failure != null) {
      throw failure;
    }

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  const _FakeSocialInteractionRecordIdGenerator();

  @override
  String generate() {
    return 'id-no-utilizado-en-edicion';
  }
}
