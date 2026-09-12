import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/exceptions/social_interaction_validation_failure.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_id_generator.dart';

class _FakeSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  const _FakeSocialInteractionRecordIdGenerator();

  @override
  String generate() {
    return 'registro-interaccion-social-001';
  }
}

void main() {
  const factory = SocialInteractionRecordFactory(
    _FakeSocialInteractionRecordIdGenerator(),
  );

  group('SocialInteractionRecordFactory', () {
    test('crea un registro de interacción social válido', () {
      final record = factory.create(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        date: DateTime(2026, 9, 11, 10, 30),
        category: SocialInteractionCategory.socialExchange,
        context: 'Actividad recreativa',
        observation: 'Registro ficticio descriptivo.',
        createdAt: DateTime.utc(2026, 9, 11, 15),
      );

      expect(record.recordId, 'registro-interaccion-social-001');

      expect(record.anonymousId, '550e8400-e29b-41d4-a716-446655440000');

      expect(record.date, DateTime(2026, 9, 11));

      expect(record.category, SocialInteractionCategory.socialExchange);

      expect(record.context, 'Actividad recreativa');

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(record.createdAt, DateTime.utc(2026, 9, 11, 15));

      expect(record.updatedAt, DateTime.utc(2026, 9, 11, 15));
    });

    test('normaliza el contexto opcional', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 11),
        category: SocialInteractionCategory.sharedActivity,
        context: '  Juego en casa  ',
      );

      expect(record.context, 'Juego en casa');
    });

    test('normaliza la observación opcional', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 11),
        category: SocialInteractionCategory.interactionResponse,
        observation: '  Respondió durante la actividad.  ',
      );

      expect(record.observation, 'Respondió durante la actividad.');
    });

    test('convierte contexto y observación vacíos en null', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 11),
        category: SocialInteractionCategory.interactionInitiation,
        context: '   ',
        observation: '',
      );

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });

    test('permite omitir contexto y observación', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 11),
        category: SocialInteractionCategory.other,
      );

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });

    test('normaliza la fecha sin conservar hora', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 11, 23, 59),
        category: SocialInteractionCategory.socialExchange,
      );

      expect(record.date, DateTime(2026, 9, 11));
    });

    test('rechaza un perfil activo vacío', () {
      expect(
        () => factory.create(
          anonymousId: '',
          date: DateTime(2026, 9, 11),
          category: SocialInteractionCategory.socialExchange,
        ),
        throwsA(
          isA<SocialInteractionValidationFailure>().having(
            (failure) => failure.errorFor('anonymousId'),
            'error del perfil',
            isNotNull,
          ),
        ),
      );
    });

    test('rechaza un identificador de perfil con separadores de ruta', () {
      expect(
        () => factory.create(
          anonymousId: 'perfil/no-valido',
          date: DateTime(2026, 9, 11),
          category: SocialInteractionCategory.socialExchange,
        ),
        throwsA(
          isA<SocialInteractionValidationFailure>().having(
            (failure) => failure.errorFor('anonymousId'),
            'error del perfil',
            isNotNull,
          ),
        ),
      );
    });
  });
}
