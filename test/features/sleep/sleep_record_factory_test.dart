import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/exceptions/sleep_validation_failure.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_id_generator.dart';

class _FakeSleepRecordIdGenerator implements SleepRecordIdGenerator {
  const _FakeSleepRecordIdGenerator();

  @override
  String generate() => 'registro-sueno-001';
}

void main() {
  const factory = SleepRecordFactory(_FakeSleepRecordIdGenerator());

  group('SleepRecordFactory', () {
    test('crea un registro de sueño válido', () {
      final record = factory.create(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        date: DateTime(2026, 9, 9),
        startTime: '22:00',
        endTime: '06:00',
        observation: 'Registro ficticio de prueba.',
        createdAt: DateTime.utc(2026, 9, 10, 11),
      );

      expect(record.recordId, 'registro-sueno-001');

      expect(record.anonymousId, '550e8400-e29b-41d4-a716-446655440000');

      expect(record.startTime, '22:00');

      expect(record.endTime, '06:00');

      expect(record.durationMinutes, 480);

      expect(record.observation, 'Registro ficticio de prueba.');

      expect(record.createdAt, DateTime.utc(2026, 9, 10, 11));

      expect(record.updatedAt, DateTime.utc(2026, 9, 10, 11));
    });

    test('normaliza la observación opcional vacía como null', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 9),
        startTime: '21:00',
        endTime: '06:30',
        observation: '   ',
      );

      expect(record.observation, isNull);
    });

    test('calcula automáticamente la duración dentro del mismo día', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 9),
        startTime: '14:00',
        endTime: '15:45',
      );

      expect(record.durationMinutes, 105);
    });

    test('calcula automáticamente la duración al cruzar medianoche', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 9),
        startTime: '23:45',
        endTime: '00:15',
      );

      expect(record.durationMinutes, 30);

      expect(record.startDateTime, DateTime(2026, 9, 9, 23, 45));

      expect(record.endDateTime, DateTime(2026, 9, 10, 0, 15));
    });

    test('utiliza la hora de inicio como fecha y hora del evento', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 9),
        startTime: '20:30',
        endTime: '06:00',
      );

      expect(record.eventDateTime, DateTime(2026, 9, 9, 20, 30));
    });

    test('rechaza horas iguales', () {
      expect(
        () => factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 9),
          startTime: '22:00',
          endTime: '22:00',
        ),
        throwsA(
          isA<SleepValidationFailure>().having(
            (failure) => failure.errorFor('endTime'),
            'error de hora final',
            isNotNull,
          ),
        ),
      );
    });

    test('rechaza una hora de inicio inválida', () {
      expect(
        () => factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 9),
          startTime: '25:00',
          endTime: '06:00',
        ),
        throwsA(
          isA<SleepValidationFailure>().having(
            (failure) => failure.errorFor('startTime'),
            'error de hora inicial',
            isNotNull,
          ),
        ),
      );
    });

    test('rechaza un perfil activo inválido', () {
      expect(
        () => factory.create(
          anonymousId: '',
          date: DateTime(2026, 9, 9),
          startTime: '22:00',
          endTime: '06:00',
        ),
        throwsA(
          isA<SleepValidationFailure>().having(
            (failure) => failure.errorFor('anonymousId'),
            'error del perfil',
            isNotNull,
          ),
        ),
      );
    });
  });
}
