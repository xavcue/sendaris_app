import 'frequency_query.dart';

class FrequencyResult {
  FrequencyResult._({required this.query, required this.count});

  factory FrequencyResult({required FrequencyQuery query, required int count}) {
    if (count < 0) {
      throw ArgumentError.value(
        count,
        'count',
        'La frecuencia no puede ser negativa.',
      );
    }

    return FrequencyResult._(query: query, count: count);
  }

  final FrequencyQuery query;

  final int count;
}
