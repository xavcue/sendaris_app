abstract final class RoutineValidator {
  static const Set<String> allowedRecurrences = {
    'diaria',
    'semanal',
    'mensual',
  };

  static Map<String, String> validate({
    required String anonymousId,
    required String name,
    String? scheduledTime,
    String? recurrence,
  }) {
    final errors = <String, String>{};

    if (anonymousId.trim().isEmpty) {
      errors['anonymousId'] = 'El seguimiento anónimo es obligatorio.';
    }

    if (name.trim().isEmpty) {
      errors['name'] = 'El nombre de la rutina es obligatorio.';
    }

    if (scheduledTime != null && !_isValidTime(scheduledTime)) {
      errors['scheduledTime'] = 'La hora programada no es válida.';
    }

    if (recurrence != null && !allowedRecurrences.contains(recurrence)) {
      errors['recurrence'] = 'La recurrencia seleccionada no es válida.';
    }

    return errors;
  }

  static bool _isValidTime(String value) {
    final match = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

    return match.hasMatch(value);
  }
}
