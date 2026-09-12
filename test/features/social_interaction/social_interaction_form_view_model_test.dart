import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/exceptions/social_interaction_failure.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_repository.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_id_generator.dart';
import 'package:sendaris/features/social_interaction/presentation/viewmodels/social_interaction_form_view_model.dart';

void main() {
  group('SocialInteractionFormViewModel', () {
    late _FakeSocialInteractionRepository repository;

    late SocialInteractionFormViewModel viewModel;

    setUp(() {
      repository = _FakeSocialInteractionRepository();

      viewModel = SocialInteractionFormViewModel(
        repository,
        const SocialInteractionRecordFactory(
          _FakeSocialInteractionRecordIdGenerator(),
        ),
        anonymousId: 'anonimo-1',
        initialDate: DateTime(2026, 9, 11, 18, 45),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('normaliza la fecha inicial sin conservar la hora', () {
      expect(viewModel.selectedDate, DateTime(2026, 9, 11));
    });

    test('inicia sin una categoría seleccionada', () {
      expect(viewModel.selectedCategory, isNull);
    });

    test('permite seleccionar una categoría general', () {
      viewModel.setCategory(SocialInteractionCategory.socialExchange);

      expect(
        viewModel.selectedCategory,
        SocialInteractionCategory.socialExchange,
      );
    });

    test('permite actualizar la fecha', () {
      viewModel.setDate(DateTime(2026, 9, 12, 23, 30));

      expect(viewModel.selectedDate, DateTime(2026, 9, 12));
    });

    test('exige seleccionar una categoría antes de guardar', () async {
      final result = await viewModel.save(context: '', observation: '');

      expect(result, false);

      expect(
        viewModel.errorFor('category'),
        'Selecciona una categoría de interacción social.',
      );

      expect(repository.savedRecords, isEmpty);
    });

    test('guarda un registro válido con contexto y observación', () async {
      viewModel.setCategory(SocialInteractionCategory.sharedActivity);

      final result = await viewModel.save(
        context: 'Actividad recreativa',
        observation: 'Registro ficticio descriptivo.',
      );

      expect(result, true);

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.anonymousId, 'anonimo-1');

      expect(record.date, DateTime(2026, 9, 11));

      expect(record.category, SocialInteractionCategory.sharedActivity);

      expect(record.context, 'Actividad recreativa');

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(
        viewModel.successMessage,
        'Registro de interacción social guardado correctamente.',
      );

      expect(viewModel.selectedCategory, isNull);
    });

    test('permite guardar sin contexto ni observación', () async {
      viewModel.setCategory(SocialInteractionCategory.interactionInitiation);

      final result = await viewModel.save(context: '', observation: '');

      expect(result, true);

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });

    test('normaliza contexto y observación mediante el Factory', () async {
      viewModel.setCategory(SocialInteractionCategory.interactionResponse);

      final result = await viewModel.save(
        context: '  Juego en casa  ',
        observation: '  Respondió durante la actividad.  ',
      );

      expect(result, true);

      final record = repository.savedRecords.single;

      expect(record.context, 'Juego en casa');

      expect(record.observation, 'Respondió durante la actividad.');
    });

    test(
      'elimina el error de categoría al seleccionar una opción válida',
      () async {
        await viewModel.save(context: '', observation: '');

        expect(viewModel.errorFor('category'), isNotNull);

        viewModel.setCategory(SocialInteractionCategory.socialExchange);

        expect(viewModel.errorFor('category'), isNull);
      },
    );

    test('presenta un error controlado cuando falla el repositorio', () async {
      repository.failure = const SocialInteractionFailure(
        'No fue posible guardar el registro de interacción social.',
      );

      viewModel.setCategory(SocialInteractionCategory.other);

      final result = await viewModel.save(context: '', observation: '');

      expect(result, false);

      expect(
        viewModel.errorMessage,
        'No fue posible guardar el registro de interacción social.',
      );

      expect(viewModel.selectedCategory, SocialInteractionCategory.other);
    });

    test('presenta un mensaje controlado ante un error inesperado', () async {
      repository.unexpectedError = Exception('Error interno');

      viewModel.setCategory(SocialInteractionCategory.interactionResponse);

      final result = await viewModel.save(context: '', observation: '');

      expect(result, false);

      expect(
        viewModel.errorMessage,
        'No fue posible guardar el registro de interacción social. '
        'Inténtalo nuevamente.',
      );
    });
  });
}

class _FakeSocialInteractionRepository implements SocialInteractionRepository {
  final List<SocialInteractionRecord> savedRecords = [];

  SocialInteractionFailure? failure;

  Object? unexpectedError;

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
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
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  const _FakeSocialInteractionRecordIdGenerator();

  @override
  String generate() {
    return 'registro-interaccion-social-view-model';
  }
}
