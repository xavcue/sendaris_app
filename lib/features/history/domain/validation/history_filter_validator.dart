abstract final class HistoryFilterValidator {
  static Map<String, String> validate({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final errors = <String, String>{};

    final hasStartDate = startDate != null;

    final hasEndDate = endDate != null;

    if (hasStartDate != hasEndDate) {
      errors['period'] = 'Selecciona una fecha inicial y una fecha final.';

      return Map.unmodifiable(errors);
    }

    if (startDate != null && endDate != null) {
      final normalizedStart = _dateOnly(startDate);

      final normalizedEnd = _dateOnly(endDate);

      if (normalizedStart.isAfter(normalizedEnd)) {
        errors['period'] =
            'La fecha inicial no puede ser posterior a la fecha final.';
      }
    }

    return Map.unmodifiable(errors);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
