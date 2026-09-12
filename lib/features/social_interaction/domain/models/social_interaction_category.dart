enum SocialInteractionCategory {
  interactionInitiation(
    code: 'inicio_interaccion',
    label: 'Inicio de interacción',
  ),

  interactionResponse(
    code: 'respuesta_interaccion',
    label: 'Respuesta a interacción',
  ),

  socialExchange(code: 'intercambio_social', label: 'Intercambio social'),

  sharedActivity(code: 'actividad_compartida', label: 'Actividad compartida'),

  other(code: 'otro', label: 'Otro');

  const SocialInteractionCategory({required this.code, required this.label});

  final String code;
  final String label;

  static SocialInteractionCategory fromCode(String code) {
    final normalizedCode = code.trim();

    for (final category in values) {
      if (category.code == normalizedCode) {
        return category;
      }
    }

    throw const FormatException(
      'La categoría de interacción social no es válida.',
    );
  }
}
