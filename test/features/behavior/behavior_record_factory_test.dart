import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/exceptions/behavior_validation_failure.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';

class _FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const _FakeBehaviorRecordIdGenerator();

  @override
  String generate() => 'registro-conducta-001';
}

void main() {
  const factory = BehaviorRecordFactory(_FakeBehaviorRecordIdGenerator());

  group('BehaviorRecordFactory', () {
    test('crea una conducta válida asociada al seguimiento anónimo', () {
      final record = factory.create(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        date: DateTime(2026, 9, 5),
        time: '14:30',
        category: BehaviorCategory.repetitiveBehavior,
        durationMinutes: 12,
        intensity: BehaviorIntensity.medium,
        context: 'Rutina de la tarde',
        observation: 'Registro ficticio de prueba.',
        createdAt: DateTime.utc(2026, 9, 5, 19, 30),
      );

      expect(record.recordId, 'registro-conducta-001');

      expect(record.anonymousId, '550e8400-e29b-41d4-a716-446655440000');

      expect(record.category, BehaviorCategory.repetitiveBehavior);

      expect(record.durationMinutes, 12);

      expect(record.time, '14:30');

      expect(record.context, 'Rutina de la tarde');

      expect(record.createdAt, DateTime.utc(2026, 9, 5, 19, 30));

      expect(record.updatedAt, DateTime.utc(2026, 9, 5, 19, 30));
    });

    test('los campos descriptivos opcionales pueden omitirse', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 5),
        category: BehaviorCategory.socialInitiative,
        createdAt: DateTime.utc(2026, 9, 5, 18),
      );

      expect(record.time, isNull);

      expect(record.durationMinutes, isNull);

      expect(record.intensity, isNull);

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });

    test('textos opcionales vacíos se normalizan como null', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 5),
        category: BehaviorCategory.avoidanceFear,
        context: '   ',
        observation: '',
        createdAt: DateTime.utc(2026, 9, 5, 18),
      );

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });

    test('rechaza una duración igual o menor que cero', () {
      expect(
        () => factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 5),
          category: BehaviorCategory.aggressionIrritability,
          durationMinutes: 0,
        ),
        throwsA(
          isA<BehaviorValidationFailure>().having(
            (failure) => failure.errorFor('durationMinutes'),
            'error de duración',
            isNotNull,
          ),
        ),
      );
    });

    test('rechaza una hora con formato inválido', () {
      expect(
        () => factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 5),
          time: '25:90',
          category: BehaviorCategory.repetitiveBehavior,
        ),
        throwsA(
          isA<BehaviorValidationFailure>().having(
            (failure) => failure.errorFor('time'),
            'error de hora',
            isNotNull,
          ),
        ),
      );
    });

    test('rechaza un identificador anónimo inválido', () {
      expect(
        () => factory.create(
          anonymousId: '',
          date: DateTime(2026, 9, 5),
          category: BehaviorCategory.repetitiveBehavior,
        ),
        throwsA(
          isA<BehaviorValidationFailure>().having(
            (failure) => failure.errorFor('anonymousId'),
            'error del seguimiento',
            isNotNull,
          ),
        ),
      );
    });

    test('combina fecha y hora para obtener la fecha del evento', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 5),
        time: '16:45',
        category: BehaviorCategory.repetitiveBehavior,
        createdAt: DateTime.utc(2026, 9, 5, 22),
      );

      expect(record.eventDateTime, DateTime(2026, 9, 5, 16, 45));
    });

    test(
      'editar conserva la identidad y la fecha de creación del registro',
      () {
        final currentRecord = _existingRecord();

        final updated = factory.update(
          currentRecord: currentRecord,
          date: DateTime(2026, 9, 20),
          time: '18:15',
          category: BehaviorCategory.socialInitiative,
          durationMinutes: 25,
          intensity: BehaviorIntensity.high,
          context: 'Actividad compartida',
          observation: 'Observación actualizada.',
          updatedAt: DateTime.utc(2026, 9, 20, 23, 15),
        );

        expect(updated.recordId, currentRecord.recordId);

        expect(updated.anonymousId, currentRecord.anonymousId);

        expect(updated.createdAt, currentRecord.createdAt);

        expect(updated.updatedAt, DateTime.utc(2026, 9, 20, 23, 15));

        expect(updated.date, DateTime(2026, 9, 20));

        expect(updated.time, '18:15');

        expect(updated.category, BehaviorCategory.socialInitiative);

        expect(updated.durationMinutes, 25);

        expect(updated.intensity, BehaviorIntensity.high);

        expect(updated.context, 'Actividad compartida');

        expect(updated.observation, 'Observación actualizada.');
      },
    );

    test('editar permite retirar campos opcionales', () {
      final updated = factory.update(
        currentRecord: _existingRecord(),
        date: DateTime(2026, 9, 20),
        category: BehaviorCategory.repetitiveBehavior,
        time: '   ',
        context: ' ',
        observation: '',
        updatedAt: DateTime.utc(2026, 9, 20, 21),
      );

      expect(updated.time, isNull);

      expect(updated.durationMinutes, isNull);

      expect(updated.intensity, isNull);

      expect(updated.context, isNull);

      expect(updated.observation, isNull);
    });

    test('editar aplica las mismas validaciones del registro de conducta', () {
      expect(
        () => factory.update(
          currentRecord: _existingRecord(),
          date: DateTime(2026, 9, 20),
          category: BehaviorCategory.repetitiveBehavior,
          time: '27:70',
          durationMinutes: 0,
        ),
        throwsA(
          isA<BehaviorValidationFailure>()
              .having(
                (failure) => failure.errorFor('time'),
                'error de hora',
                isNotNull,
              )
              .having(
                (failure) => failure.errorFor('durationMinutes'),
                'error de duración',
                isNotNull,
              ),
        ),
      );
    });
  });
}

BehaviorRecord _existingRecord() {
  return BehaviorRecord(
    recordId: 'conducta-existente-001',
    anonymousId: 'seguimiento-anonimo',
    date: DateTime(2026, 9, 15),
    time: '14:30',
    category: BehaviorCategory.avoidanceFear,
    durationMinutes: 10,
    intensity: BehaviorIntensity.medium,
    context: 'Contexto original',
    observation: 'Observación original.',
    createdAt: DateTime.utc(2026, 9, 15, 19, 30),
    updatedAt: DateTime.utc(2026, 9, 15, 19, 30),
  );
}
