import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/domain/exceptions/history_filter_validation_failure.dart';
import 'package:sendaris/features/history/domain/models/history_filter.dart';
import 'package:sendaris/features/history/domain/models/history_record.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';

void main() {
  group('HistoryFilter', () {
    test('el filtro vacío está inactivo y acepta cualquier registro', () {
      final filter = HistoryFilter.empty();

      expect(filter.isActive, isFalse);

      expect(filter.hasPeriodFilter, isFalse);

      expect(filter.hasTypeFilter, isFalse);

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isTrue,
      );
    });

    test('normaliza las fechas del periodo eliminando la hora', () {
      final filter = HistoryFilter.create(
        startDate: DateTime(2026, 9, 5, 15, 30),
        endDate: DateTime(2026, 9, 15, 23, 59),
      );

      expect(filter.startDate, DateTime(2026, 9, 5));

      expect(filter.endDate, DateTime(2026, 9, 15));
    });

    test('incluye registros correspondientes a la fecha inicial', () {
      final filter = HistoryFilter.create(
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 5, 8),
          ),
        ),
        isTrue,
      );
    });

    test('incluye registros correspondientes a la fecha final', () {
      final filter = HistoryFilter.create(
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.sleep,
            eventDate: DateTime(2026, 9, 15, 22),
          ),
        ),
        isTrue,
      );
    });

    test('excluye registros anteriores al periodo', () {
      final filter = HistoryFilter.create(
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 4),
          ),
        ),
        isFalse,
      );
    });

    test('excluye registros posteriores al periodo', () {
      final filter = HistoryFilter.create(
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 16),
          ),
        ),
        isFalse,
      );
    });

    test('permite filtrar por un solo tipo de registro', () {
      final filter = HistoryFilter.create(
        selectedTypes: {HistoryRecordType.dysregulation},
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.dysregulation,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isTrue,
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.sleep,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isFalse,
      );
    });

    test('permite seleccionar más de un tipo de registro', () {
      final filter = HistoryFilter.create(
        selectedTypes: {HistoryRecordType.behavior, HistoryRecordType.sleep},
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isTrue,
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.sleep,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isTrue,
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.feeding,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isFalse,
      );
    });

    test('combina periodo y tipos utilizando ambos criterios', () {
      final filter = HistoryFilter.create(
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 15),
        selectedTypes: {
          HistoryRecordType.behavior,
          HistoryRecordType.dysregulation,
        },
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.dysregulation,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isTrue,
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.sleep,
            eventDate: DateTime(2026, 9, 15),
          ),
        ),
        isFalse,
      );

      expect(
        filter.matches(
          _record(
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 9),
          ),
        ),
        isFalse,
      );
    });

    test('rechaza la creación de un filtro con periodo inválido', () {
      expect(
        () => HistoryFilter.create(
          startDate: DateTime(2026, 9, 16),
          endDate: DateTime(2026, 9, 15),
        ),
        throwsA(isA<HistoryFilterValidationFailure>()),
      );
    });

    test(
      'la colección de tipos seleccionados no puede modificarse externamente',
      () {
        final filter = HistoryFilter.create(
          selectedTypes: {HistoryRecordType.behavior},
        );

        expect(
          () => filter.selectedTypes.add(HistoryRecordType.sleep),
          throwsUnsupportedError,
        );
      },
    );
  });
}

HistoryRecord _record({
  required HistoryRecordType type,
  required DateTime eventDate,
}) {
  return HistoryRecord(
    recordId: 'registro-prueba',
    anonymousId: 'perfil-prueba',
    type: type,
    eventDate: eventDate,
  );
}
