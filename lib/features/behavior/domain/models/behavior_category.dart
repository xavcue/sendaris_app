enum BehaviorCategory {
  aggressionIrritability(
    code: 'agresion_irritabilidad',
    label: 'Agresión o irritabilidad',
  ),
  avoidanceFear(code: 'evitacion_miedo', label: 'Evitación o miedo'),
  repetitiveBehavior(code: 'conducta_repetitiva', label: 'Conducta repetitiva'),
  socialInitiative(code: 'iniciativa_social', label: 'Iniciativa social');

  const BehaviorCategory({required this.code, required this.label});

  final String code;
  final String label;

  static BehaviorCategory fromCode(String code) {
    for (final category in values) {
      if (category.code == code) {
        return category;
      }
    }

    throw FormatException('Categoría de conducta no reconocida: $code');
  }
}
