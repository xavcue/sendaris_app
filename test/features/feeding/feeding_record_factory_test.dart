import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/exceptions/feeding_validation_failure.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_id_generator.dart';

class _FakeFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  const _FakeFeedingRecordIdGenerator();

  @override
  String generate() {
    return 'registro-alimentacion-001';
  }
}

void main() {
  const factory = FeedingRecordFactory(_FakeFeedingRecordIdGenerator());

  group('FeedingRecordFactory', () {
    test('crea un registro de alimentación válido', () {
      final record = factory.create(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        date: DateTime(2026, 9, 10, 18, 45),
        category: FeedingCategory.lunch,
        observation: 'Registro ficticio de prueba.',
        createdAt: DateTime.utc(2026, 9, 10, 20),
      );

      expect(record.recordId, 'registro-alimentacion-001');

      expect(record.anonymousId, '550e8400-e29b-41d4-a716-446655440000');

      expect(record.date, DateTime(2026, 9, 10));

      expect(record.category, FeedingCategory.lunch);

      expect(record.observation, 'Registro ficticio de prueba.');

      expect(record.createdAt, DateTime.utc(2026, 9, 10, 20));

      expect(record.updatedAt, DateTime.utc(2026, 9, 10, 20));
    });

    test('normaliza la observación opcional', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 10),
        category: FeedingCategory.breakfast,
        observation: '  Comida realizada durante la rutina habitual.  ',
      );

      expect(
        record.observation,
        'Comida realizada durante la rutina habitual.',
      );
    });

    test('convierte una observación vacía en null', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 10),
        category: FeedingCategory.snack,
        observation: '   ',
      );

      expect(record.observation, isNull);
    });

    test('permite omitir completamente la observación', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 10),
        category: FeedingCategory.afternoonMealOrDinner,
      );

      expect(record.observation, isNull);
    });

    test('normaliza la fecha sin conservar hora', () {
      final record = factory.create(
        anonymousId: 'perfil-anonimo',
        date: DateTime(2026, 9, 10, 23, 59),
        category: FeedingCategory.other,
      );

      expect(record.date, DateTime(2026, 9, 10));
    });

    test('rechaza un perfil activo vacío', () {
      expect(
        () => factory.create(
          anonymousId: '',
          date: DateTime(2026, 9, 10),
          category: FeedingCategory.lunch,
        ),
        throwsA(
          isA<FeedingValidationFailure>().having(
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
          date: DateTime(2026, 9, 10),
          category: FeedingCategory.lunch,
        ),
        throwsA(
          isA<FeedingValidationFailure>().having(
            (failure) => failure.errorFor('anonymousId'),
            'error del perfil',
            isNotNull,
          ),
        ),
      );
    });

    test(
      'actualiza los campos editables preservando la identidad y creación',
      () {
        final current = FeedingRecord(
          recordId: 'alimentacion-existente',
          anonymousId: 'seguimiento-actual',
          date: DateTime(2026, 9, 10),
          category: FeedingCategory.breakfast,
          observation: 'Observación inicial.',
          createdAt: DateTime.utc(2026, 9, 10, 12),
          updatedAt: DateTime.utc(2026, 9, 10, 12),
        );

        final updated = factory.update(
          currentRecord: current,
          date: DateTime(2026, 9, 12, 18, 30),
          category: FeedingCategory.lunch,
          observation: '  Observación actualizada.  ',
          updatedAt: DateTime.utc(2026, 9, 12, 20),
        );

        expect(updated.recordId, current.recordId);

        expect(updated.anonymousId, current.anonymousId);

        expect(updated.createdAt, current.createdAt);

        expect(updated.date, DateTime(2026, 9, 12));

        expect(updated.category, FeedingCategory.lunch);

        expect(updated.observation, 'Observación actualizada.');

        expect(updated.updatedAt, DateTime.utc(2026, 9, 12, 20));
      },
    );

    test('actualizar permite retirar la observación opcional', () {
      final current = FeedingRecord(
        recordId: 'alimentacion-existente',
        anonymousId: 'seguimiento-actual',
        date: DateTime(2026, 9, 10),
        category: FeedingCategory.breakfast,
        observation: 'Observación inicial.',
        createdAt: DateTime.utc(2026, 9, 10, 12),
        updatedAt: DateTime.utc(2026, 9, 10, 12),
      );

      final updated = factory.update(
        currentRecord: current,
        date: DateTime(2026, 9, 10),
        category: FeedingCategory.breakfast,
        observation: '   ',
        updatedAt: DateTime.utc(2026, 9, 10, 13),
      );

      expect(updated.observation, isNull);

      expect(updated.recordId, current.recordId);

      expect(updated.createdAt, current.createdAt);
    });
  });
}
