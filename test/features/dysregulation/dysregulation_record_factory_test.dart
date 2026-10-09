import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/exceptions/dysregulation_validation_failure.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';

class _FakeDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  const _FakeDysregulationRecordIdGenerator();

  @override
  String generate() {
    return 'registro-desregulacion-001';
  }
}

void main() {
  const factory = DysregulationRecordFactory(
    _FakeDysregulationRecordIdGenerator(),
  );

  group('DysregulationRecordFactory', () {
    test('crea un episodio válido asociado al seguimiento anónimo', () {
      final record = factory.create(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        date: DateTime(2026, 9, 15),
        time: '14:30',
        durationMinutes: 12,
        intensity: DysregulationIntensity.medium,
        context: 'Durante una actividad cotidiana',
        observation: 'Registro ficticio descriptivo.',
        createdAt: DateTime.utc(2026, 9, 15, 19, 30),
      );

      expect(record.recordId, 'registro-desregulacion-001');

      expect(record.anonymousId, '550e8400-e29b-41d4-a716-446655440000');

      expect(record.date, DateTime(2026, 9, 15));

      expect(record.time, '14:30');

      expect(record.durationMinutes, 12);

      expect(record.intensity, DysregulationIntensity.medium);

      expect(record.context, 'Durante una actividad cotidiana');

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(record.createdAt, DateTime.utc(2026, 9, 15, 19, 30));

      expect(record.updatedAt, DateTime.utc(2026, 9, 15, 19, 30));
    });

    test('los campos descriptivos opcionales pueden omitirse', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 15),
        createdAt: DateTime.utc(2026, 9, 15, 18),
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
        date: DateTime(2026, 9, 15),
        time: '   ',
        context: '   ',
        observation: '',
        createdAt: DateTime.utc(2026, 9, 15, 18),
      );

      expect(record.time, isNull);

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });

    test('permite una duración igual a cero porque no es negativa', () {
      final record = factory.create(
        anonymousId: 'seguimiento-anonimo',
        date: DateTime(2026, 9, 15),
        durationMinutes: 0,
        createdAt: DateTime.utc(2026, 9, 15, 18),
      );

      expect(record.durationMinutes, 0);
    });

    test('rechaza una duración negativa', () {
      expect(
        () => factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 15),
          durationMinutes: -1,
        ),
        throwsA(
          isA<DysregulationValidationFailure>().having(
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
          date: DateTime(2026, 9, 15),
          time: '25:90',
        ),
        throwsA(
          isA<DysregulationValidationFailure>().having(
            (failure) => failure.errorFor('time'),
            'error de hora',
            isNotNull,
          ),
        ),
      );
    });

    test('rechaza un identificador anónimo inválido', () {
      expect(
        () => factory.create(anonymousId: '', date: DateTime(2026, 9, 15)),
        throwsA(
          isA<DysregulationValidationFailure>().having(
            (failure) => failure.errorFor('anonymousId'),
            'error del seguimiento',
            isNotNull,
          ),
        ),
      );
    });

    test(
      'combina fecha y hora para obtener la fecha efectiva del episodio',
      () {
        final record = factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 15),
          time: '16:45',
          createdAt: DateTime.utc(2026, 9, 15, 22),
        );

        expect(record.eventDateTime, DateTime(2026, 9, 15, 16, 45));
      },
    );

    test(
      'sin hora usa únicamente la fecha como fecha efectiva del episodio',
      () {
        final record = factory.create(
          anonymousId: 'seguimiento-anonimo',
          date: DateTime(2026, 9, 15),
          createdAt: DateTime.utc(2026, 9, 15, 22),
        );

        expect(record.eventDateTime, DateTime(2026, 9, 15));
      },
    );

    test('actualiza los datos conservando identidad y fecha de creación', () {
      final currentRecord = _currentRecord();

      final updated = factory.update(
        currentRecord: currentRecord,
        date: DateTime(2026, 9, 20, 23, 59),
        time: '18:40',
        durationMinutes: 25,
        intensity: DysregulationIntensity.high,
        context: 'Cambio de actividad',
        observation: 'Registro actualizado.',
        updatedAt: DateTime.utc(2026, 9, 20, 23),
      );

      expect(updated.recordId, currentRecord.recordId);

      expect(updated.anonymousId, currentRecord.anonymousId);

      expect(updated.createdAt, currentRecord.createdAt);

      expect(updated.updatedAt, DateTime.utc(2026, 9, 20, 23));

      expect(updated.date, DateTime(2026, 9, 20));

      expect(updated.time, '18:40');

      expect(updated.durationMinutes, 25);

      expect(updated.intensity, DysregulationIntensity.high);

      expect(updated.context, 'Cambio de actividad');

      expect(updated.observation, 'Registro actualizado.');
    });

    test('una actualización puede retirar todos los campos opcionales', () {
      final updated = factory.update(
        currentRecord: _currentRecord(),
        date: DateTime(2026, 9, 20),
        time: '   ',
        durationMinutes: null,
        intensity: null,
        context: '   ',
        observation: '',
        updatedAt: DateTime.utc(2026, 9, 20, 23),
      );

      expect(updated.time, isNull);

      expect(updated.durationMinutes, isNull);

      expect(updated.intensity, isNull);

      expect(updated.context, isNull);

      expect(updated.observation, isNull);
    });
  });
}

DysregulationRecord _currentRecord() {
  return DysregulationRecord(
    recordId: 'desregulacion-actual',
    anonymousId: 'seguimiento-anonimo',
    date: DateTime(2026, 9, 15),
    time: '14:30',
    durationMinutes: 12,
    intensity: DysregulationIntensity.medium,
    context: 'Actividad cotidiana',
    observation: 'Registro inicial.',
    createdAt: DateTime.utc(2026, 9, 15, 20),
    updatedAt: DateTime.utc(2026, 9, 15, 20),
  );
}
