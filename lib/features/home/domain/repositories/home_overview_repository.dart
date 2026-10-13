import '../models/home_day_overview.dart';

abstract interface class HomeOverviewRepository {
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  });
}
