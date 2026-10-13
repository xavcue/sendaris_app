import 'home_activity_area.dart';

class HomeDayOverview {
  factory HomeDayOverview({
    required DateTime date,
    Map<HomeActivityArea, int>? recordCounts,
    Map<HomeActivityArea, int>? counts,
    Set<HomeActivityArea>? areas,
  }) {
    if (recordCounts != null && counts != null) {
      throw ArgumentError('Usa recordCounts o counts, pero no ambos.');
    }

    final sourceCounts = recordCounts ?? counts;

    final normalizedCounts = _normalizeRecordCounts(
      sourceCounts: sourceCounts,
      visibleAreas: areas,
    );

    return HomeDayOverview._(
      date: DateTime(date.year, date.month, date.day),
      recordCounts: Map<HomeActivityArea, int>.unmodifiable(normalizedCounts),
    );
  }

  const HomeDayOverview._({required this.date, required this.recordCounts});

  final DateTime date;

  final Map<HomeActivityArea, int> recordCounts;

  Map<HomeActivityArea, int> get counts {
    return recordCounts;
  }

  Set<HomeActivityArea> get areas {
    return Set<HomeActivityArea>.unmodifiable(recordCounts.keys);
  }

  List<HomeActivityArea> get orderedAreas {
    return HomeActivityArea.values
        .where(recordCounts.containsKey)
        .toList(growable: false);
  }

  bool get hasActivity {
    return recordCounts.isNotEmpty;
  }

  bool get isEmpty {
    return recordCounts.isEmpty;
  }

  bool contains(HomeActivityArea area) {
    return recordCounts.containsKey(area);
  }

  int countFor(HomeActivityArea area) {
    return recordCounts[area] ?? 0;
  }

  static Map<HomeActivityArea, int> _normalizeRecordCounts({
    required Map<HomeActivityArea, int>? sourceCounts,
    required Set<HomeActivityArea>? visibleAreas,
  }) {
    if (visibleAreas != null) {
      if (sourceCounts == null) {
        return <HomeActivityArea, int>{
          for (final area in visibleAreas) area: 1,
        };
      }

      final normalized = <HomeActivityArea, int>{};

      for (final area in visibleAreas) {
        final count = sourceCounts[area];

        if (count == null || count <= 0) {
          throw ArgumentError.value(
            count,
            'counts',
            'Cada área visible debe tener un conteo mayor que cero.',
          );
        }

        normalized[area] = count;
      }

      return normalized;
    }

    if (sourceCounts == null) {
      return <HomeActivityArea, int>{};
    }

    return <HomeActivityArea, int>{
      for (final entry in sourceCounts.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
  }
}
