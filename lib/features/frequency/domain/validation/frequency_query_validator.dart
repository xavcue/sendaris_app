import '../models/frequency_metric_type.dart';

abstract final class FrequencyQueryValidator {
  static Map<String, String> validate({
    required String anonymousId,
    required FrequencyMetricType metricType,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryCode,
  }) {
    final errors = <String, String>{};

    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      errors['anonymousId'] = 'El perfil activo no es válido.';
    }

    if (startDate == null || endDate == null) {
      errors['period'] = 'Selecciona una fecha inicial y una fecha final.';
    } else {
      final normalizedStart = _dateOnly(startDate);

      final normalizedEnd = _dateOnly(endDate);

      if (normalizedStart.isAfter(normalizedEnd)) {
        errors['period'] =
            'La fecha inicial no puede ser posterior a la fecha final.';
      }
    }

    final normalizedCategory = categoryCode?.trim();

    switch (metricType.categoryMode) {
      case FrequencyCategoryMode.none:
        if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
          errors['category'] = 'La métrica seleccionada no utiliza categorías.';
        }

      case FrequencyCategoryMode.required:
        if (normalizedCategory == null || normalizedCategory.isEmpty) {
          errors['category'] = 'Selecciona una categoría aplicable.';
        } else if (!metricType.isValidCategoryCode(normalizedCategory)) {
          errors['category'] = 'La categoría seleccionada no es válida.';
        }

      case FrequencyCategoryMode.optional:
        if (normalizedCategory != null &&
            normalizedCategory.isNotEmpty &&
            !metricType.isValidCategoryCode(normalizedCategory)) {
          errors['category'] = 'La categoría seleccionada no es válida.';
        }
    }

    return Map.unmodifiable(errors);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
