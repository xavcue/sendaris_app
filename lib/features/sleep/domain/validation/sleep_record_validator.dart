abstract final class SleepRecordValidator {
  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static Map<String, String> validate({
    required String anonymousId,
    required String startTime,
    required String endTime,
  }) {
    final errors = <String, String>{};

    final normalizedAnonymousId = anonymousId.trim();

    final normalizedStartTime = startTime.trim();

    final normalizedEndTime = endTime.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      errors['anonymousId'] = 'El perfil activo no es válido.';
    }

    final startTimeIsValid = _timePattern.hasMatch(normalizedStartTime);

    final endTimeIsValid = _timePattern.hasMatch(normalizedEndTime);

    if (!startTimeIsValid) {
      errors['startTime'] =
          'La hora de inicio debe tener un formato válido de 00:00 a 23:59.';
    }

    if (!endTimeIsValid) {
      errors['endTime'] = 'La hora de finalización debe tener un formato válido de 00:00 a 23:59.';
    }

    if (startTimeIsValid &&
        endTimeIsValid &&
        normalizedStartTime == normalizedEndTime) {
      errors['endTime'] =
          'La hora de finalización debe ser distinta de la hora de inicio.';
    }

    return Map.unmodifiable(errors);
  }
}
