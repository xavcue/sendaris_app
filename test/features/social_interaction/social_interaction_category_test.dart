import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';

void main() {
  group('SocialInteractionCategory', () {
    test('contiene únicamente el catálogo general definido para HU07', () {
      expect(
        SocialInteractionCategory.values
            .map((category) => category.code)
            .toList(),
        [
          'inicio_interaccion',
          'respuesta_interaccion',
          'intercambio_social',
          'actividad_compartida',
          'otro',
        ],
      );
    });

    test('recupera una categoría mediante su código', () {
      expect(
        SocialInteractionCategory.fromCode('intercambio_social'),
        SocialInteractionCategory.socialExchange,
      );

      expect(
        SocialInteractionCategory.fromCode('  actividad_compartida  '),
        SocialInteractionCategory.sharedActivity,
      );
    });

    test('rechaza una categoría valorativa fuera del catálogo', () {
      expect(
        () => SocialInteractionCategory.fromCode('buena_interaccion'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
