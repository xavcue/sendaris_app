enum FeedingCategory {
  breakfast(code: 'desayuno', label: 'Desayuno'),

  snack(code: 'refrigerio', label: 'Refrigerio'),

  lunch(code: 'almuerzo', label: 'Almuerzo'),

  afternoonMealOrDinner(code: 'merienda_cena', label: 'Merienda / cena'),

  other(code: 'otro', label: 'Otro');

  const FeedingCategory({required this.code, required this.label});

  final String code;
  final String label;

  static FeedingCategory fromCode(String code) {
    final normalizedCode = code.trim();

    for (final category in values) {
      if (category.code == normalizedCode) {
        return category;
      }
    }

    throw const FormatException('La categoría de alimentación no es válida.');
  }
}
