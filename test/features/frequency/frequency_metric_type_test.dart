import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';

void main() {
  group('FrequencyMetricType', () {
    test('expone exactamente las cinco métricas de frecuencia definidas', () {
      expect(FrequencyMetricType.values, hasLength(5));

      expect(
        FrequencyMetricType.values
            .map((metric) => metric.indicatorCode)
            .toList(),
        ['IND-04', 'IND-06', 'IND-08', 'IND-11', 'IND-12'],
      );
    });

    test('conducta reutiliza el catálogo definitivo de categorías', () {
      expect(
        FrequencyMetricType.behavior.categoryOptions
            .map((option) => option.code)
            .toList(),
        BehaviorCategory.values.map((category) => category.code).toList(),
      );
    });

    test('interacción social reutiliza su catálogo de categorías', () {
      expect(
        FrequencyMetricType.socialInteraction.categoryOptions
            .map((option) => option.code)
            .toList(),
        SocialInteractionCategory.values
            .map((category) => category.code)
            .toList(),
      );
    });

    test('alimentación reutiliza su catálogo de categorías', () {
      expect(
        FrequencyMetricType.feeding.categoryOptions
            .map((option) => option.code)
            .toList(),
        FeedingCategory.values.map((category) => category.code).toList(),
      );
    });

    test('situaciones atípicas reutilizan su catálogo y permiten categoría opcional', () {
      expect(
        FrequencyMetricType.atypicalSituation.categoryMode,
        FrequencyCategoryMode.optional,
      );

      expect(
        FrequencyMetricType.atypicalSituation.categoryOptions
            .map((option) => option.code)
            .toList(),
        AtypicalSituationCategory.values
            .map((category) => category.code)
            .toList(),
      );
    });

    test('desregulación no utiliza categorías', () {
      expect(
        FrequencyMetricType.dysregulation.categoryMode,
        FrequencyCategoryMode.none,
      );

      expect(FrequencyMetricType.dysregulation.categoryOptions, isEmpty);
    });
  });
}
