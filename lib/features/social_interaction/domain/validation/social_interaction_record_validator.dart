abstract final class SocialInteractionRecordValidator {
  static Map<String, String> validate({required String anonymousId}) {
    final errors = <String, String>{};

    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      errors['anonymousId'] = 'El perfil activo no es válido.';
    }

    return Map.unmodifiable(errors);
  }
}
