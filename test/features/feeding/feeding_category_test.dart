import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';

void main() {
  group('FeedingCategory', () {
    test('contiene únicamente el catálogo general definido para HU06', () {
      expect(FeedingCategory.values.map((category) => category.code).toList(), [
        'desayuno',
        'refrigerio',
        'almuerzo',
        'merienda_cena',
        'otro',
      ]);
    });

    test('recupera una categoría mediante su código', () {
      expect(FeedingCategory.fromCode('almuerzo'), FeedingCategory.lunch);

      expect(FeedingCategory.fromCode('  refrigerio  '), FeedingCategory.snack);
    });

    test('rechaza una categoría fuera del catálogo', () {
      expect(
        () => FeedingCategory.fromCode('saludable'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
