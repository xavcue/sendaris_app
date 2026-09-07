import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/exceptions/atypical_situation_validation_failure.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';

void main() {
  group('AtypicalSituationRecordFactory', () {
    test('crea un registro válido normalizando los textos', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      final createdAt = DateTime.utc(2026, 9, 7, 12, 30);

      final record = factory.create(
        anonymousId: '  anonimo-test  ',
        date: DateTime(2026, 9, 6, 18, 30),
        category: AtypicalSituationCategory.unexpectedEvent,
        observation: '  Se suspendió una actividad programada.  ',
        createdAt: createdAt,
      );

      expect(record.recordId, 'situacion-atipica-test');

      expect(record.anonymousId, 'anonimo-test');

      expect(record.date, DateTime(2026, 9, 6));

      expect(record.category, AtypicalSituationCategory.unexpectedEvent);

      expect(record.observation, 'Se suspendió una actividad programada.');

      expect(record.createdAt, createdAt);

      expect(record.updatedAt, createdAt);
    });

    test('rechaza una observación vacía', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      expect(
        () => factory.create(
          anonymousId: 'anonimo-test',
          date: DateTime(2026, 9, 6),
          category: AtypicalSituationCategory.other,
          observation: '   ',
        ),
        throwsA(isA<AtypicalSituationValidationFailure>()),
      );
    });

    test('rechaza un identificador de perfil inválido', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      expect(
        () => factory.create(
          anonymousId: 'perfil/invalido',
          date: DateTime(2026, 9, 6),
          category: AtypicalSituationCategory.environmentChange,
          observation: 'Se realizó la actividad en otro lugar.',
        ),
        throwsA(isA<AtypicalSituationValidationFailure>()),
      );
    });
  });
}

class _FakeAtypicalSituationRecordIdGenerator
    implements AtypicalSituationRecordIdGenerator {
  const _FakeAtypicalSituationRecordIdGenerator();

  @override
  String generate() {
    return 'situacion-atipica-test';
  }
}
