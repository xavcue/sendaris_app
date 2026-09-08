abstract final class BehaviorRecordValidator {
  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static Map<String, String> validate({
    required String anonymousId,
    String? time,
    int? durationMinutes,
  }) {
    final errors = <String, String>{};

    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      errors['anonymousId'] = 'El perfil activo no es válido.';
    }

    final normalizedTime = time?.trim();

    if (normalizedTime != null &&
        normalizedTime.isNotEmpty &&
        !_timePattern.hasMatch(normalizedTime)) {
      errors['time'] = 'La hora debe tener un formato válido de 00:00 a 23:59.';
    }

    if (durationMinutes != null && durationMinutes <= 0) {
      errors['durationMinutes'] = 'La duración debe ser mayor que cero.';
    }

    return Map.unmodifiable(errors);
  }
}
