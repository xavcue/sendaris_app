import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/exceptions/atypical_situation_validation_failure.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
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

    test('rechaza una observación vacía al crear', () {
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

    test('rechaza un identificador de seguimiento inválido al crear', () {
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

    test('actualiza preservando identidad y fecha de creación', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      final currentRecord = _record();

      final updatedAt = DateTime.utc(2026, 9, 23, 18);

      final updated = factory.update(
        currentRecord: currentRecord,
        date: DateTime(2026, 9, 23, 21, 45),
        category: AtypicalSituationCategory.scheduleChange,
        observation: '  Se modificó el horario previsto.  ',
        updatedAt: updatedAt,
      );

      expect(updated.recordId, currentRecord.recordId);

      expect(updated.anonymousId, currentRecord.anonymousId);

      expect(updated.createdAt, currentRecord.createdAt);

      expect(updated.date, DateTime(2026, 9, 23));

      expect(updated.category, AtypicalSituationCategory.scheduleChange);

      expect(updated.observation, 'Se modificó el horario previsto.');

      expect(updated.updatedAt, updatedAt);
    });

    test('normaliza la fecha durante la actualización', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      final updated = factory.update(
        currentRecord: _record(),
        date: DateTime(2026, 9, 25, 23, 59),
        category: AtypicalSituationCategory.other,
        observation: 'Descripción actualizada.',
      );

      expect(updated.date, DateTime(2026, 9, 25));
    });

    test('rechaza una descripción vacía al actualizar', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      expect(
        () => factory.update(
          currentRecord: _record(),
          date: DateTime(2026, 9, 23),
          category: AtypicalSituationCategory.other,
          observation: '   ',
        ),
        throwsA(isA<AtypicalSituationValidationFailure>()),
      );
    });

    test('rechaza un seguimiento inválido durante la actualización', () {
      const factory = AtypicalSituationRecordFactory(
        _FakeAtypicalSituationRecordIdGenerator(),
      );

      final invalidRecord = AtypicalSituationRecord(
        recordId: 'registro-1',
        anonymousId: 'seguimiento/invalido',
        date: DateTime(2026, 9, 22),
        category: AtypicalSituationCategory.other,
        observation: 'Descripción válida.',
        createdAt: DateTime.utc(2026, 9, 22, 12),
        updatedAt: DateTime.utc(2026, 9, 22, 12),
      );

      expect(
        () => factory.update(
          currentRecord: invalidRecord,
          date: DateTime(2026, 9, 23),
          category: AtypicalSituationCategory.other,
          observation: 'Descripción válida.',
        ),
        throwsA(isA<AtypicalSituationValidationFailure>()),
      );
    });
  });
}

AtypicalSituationRecord _record() {
  return AtypicalSituationRecord(
    recordId: 'situacion-existente',
    anonymousId: 'anonimo-test',
    date: DateTime(2026, 9, 22),
    category: AtypicalSituationCategory.unexpectedEvent,
    observation: 'Situación inicial.',
    createdAt: DateTime.utc(2026, 9, 22, 12),
    updatedAt: DateTime.utc(2026, 9, 22, 12),
  );
}

class _FakeAtypicalSituationRecordIdGenerator
    implements AtypicalSituationRecordIdGenerator {
  const _FakeAtypicalSituationRecordIdGenerator();

  @override
  String generate() {
    return 'situacion-atipica-test';
  }
}
