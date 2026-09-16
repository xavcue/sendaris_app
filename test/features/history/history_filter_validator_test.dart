import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/domain/validation/history_filter_validator.dart';

void main() {
  group('HistoryFilterValidator', () {
    test(
      'acepta un periodo sin fechas porque representa ausencia de filtro',
      () {
        final errors = HistoryFilterValidator.validate();

        expect(errors, isEmpty);
      },
    );

    test('acepta una fecha inicial y final válidas', () {
      final errors = HistoryFilterValidator.validate(
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors, isEmpty);
    });

    test('acepta el mismo día como inicio y fin', () {
      final errors = HistoryFilterValidator.validate(
        startDate: DateTime(2026, 9, 15, 8),
        endDate: DateTime(2026, 9, 15, 18),
      );

      expect(errors, isEmpty);
    });

    test('rechaza una fecha inicial sin fecha final', () {
      final errors = HistoryFilterValidator.validate(
        startDate: DateTime(2026, 9, 5),
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza una fecha final sin fecha inicial', () {
      final errors = HistoryFilterValidator.validate(
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza una fecha inicial posterior a la fecha final', () {
      final errors = HistoryFilterValidator.validate(
        startDate: DateTime(2026, 9, 16),
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        errors['period'],
        'La fecha inicial no puede ser posterior a la fecha final.',
      );
    });
  });
}
