import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';

import 'frequency_category_option.dart';

enum FrequencyCategoryMode { none, required, optional }

enum FrequencyMetricType {
  behavior(
    code: 'conducta',
    indicatorCode: 'IND-04',
    label: 'Conductas registradas',
    categoryMode: FrequencyCategoryMode.required,
  ),

  dysregulation(
    code: 'desregulacion',
    indicatorCode: 'IND-06',
    label: 'Episodios de desregulación emocional',
    categoryMode: FrequencyCategoryMode.none,
  ),

  socialInteraction(
    code: 'interaccionSocial',
    indicatorCode: 'IND-08',
    label: 'Interacciones sociales registradas',
    categoryMode: FrequencyCategoryMode.required,
  ),

  feeding(
    code: 'alimentacion',
    indicatorCode: 'IND-11',
    label: 'Registros de alimentación',
    categoryMode: FrequencyCategoryMode.required,
  ),

  atypicalSituation(
    code: 'situacionAtipica',
    indicatorCode: 'IND-12',
    label: 'Situaciones atípicas registradas',
    categoryMode: FrequencyCategoryMode.optional,
  );

  const FrequencyMetricType({
    required this.code,
    required this.indicatorCode,
    required this.label,
    required this.categoryMode,
  });

  final String code;
  final String indicatorCode;
  final String label;
  final FrequencyCategoryMode categoryMode;

  bool get supportsCategories => categoryMode != FrequencyCategoryMode.none;

  bool get requiresCategory => categoryMode == FrequencyCategoryMode.required;

  List<FrequencyCategoryOption> get categoryOptions {
    switch (this) {
      case FrequencyMetricType.behavior:
        return List.unmodifiable(
          BehaviorCategory.values.map(
            (category) => FrequencyCategoryOption(
              code: category.code,
              label: category.label,
            ),
          ),
        );

      case FrequencyMetricType.dysregulation:
        return const <FrequencyCategoryOption>[];

      case FrequencyMetricType.socialInteraction:
        return List.unmodifiable(
          SocialInteractionCategory.values.map(
            (category) => FrequencyCategoryOption(
              code: category.code,
              label: category.label,
            ),
          ),
        );

      case FrequencyMetricType.feeding:
        return List.unmodifiable(
          FeedingCategory.values.map(
            (category) => FrequencyCategoryOption(
              code: category.code,
              label: category.label,
            ),
          ),
        );

      case FrequencyMetricType.atypicalSituation:
        return List.unmodifiable(
          AtypicalSituationCategory.values.map(
            (category) => FrequencyCategoryOption(
              code: category.code,
              label: category.label,
            ),
          ),
        );
    }
  }

  bool isValidCategoryCode(String code) {
    final normalizedCode = code.trim();

    return categoryOptions.any((option) => option.code == normalizedCode);
  }
}
