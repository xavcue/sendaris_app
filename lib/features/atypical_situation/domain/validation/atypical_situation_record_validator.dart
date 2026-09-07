abstract final class AtypicalSituationRecordValidator {
  static Map<String, String> validate({
    required String anonymousId,
    required String observation,
  }) {
    final errors = <String, String>{};

    final normalizedAnonymousId = anonymousId.trim();

    final normalizedObservation = observation.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      errors['anonymousId'] = 'El perfil seleccionado no es válido.';
    }

    if (normalizedObservation.isEmpty) {
      errors['observation'] = 'Describe brevemente la situación.';
    }

    return Map.unmodifiable(errors);
  }
}
