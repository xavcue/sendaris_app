enum HomeGreetingPeriod { morning, afternoon, night }

abstract final class HomeTemporalContext {
  static HomeGreetingPeriod greetingPeriodFor(DateTime localDateTime) {
    final hour = localDateTime.hour;

    if (hour >= 5 && hour < 12) {
      return HomeGreetingPeriod.morning;
    }

    if (hour >= 12 && hour < 19) {
      return HomeGreetingPeriod.afternoon;
    }

    return HomeGreetingPeriod.night;
  }

  static String greetingFor(DateTime localDateTime) {
    return switch (greetingPeriodFor(localDateTime)) {
      HomeGreetingPeriod.morning => 'Buenos días',
      HomeGreetingPeriod.afternoon => 'Buenas tardes',
      HomeGreetingPeriod.night => 'Buenas noches',
    };
  }

  static DateTime localDateFor(DateTime localDateTime) {
    return DateTime(localDateTime.year, localDateTime.month, localDateTime.day);
  }

  static DateTime nextTemporalBoundaryAfter(DateTime localDateTime) {
    final nextMidnight = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day + 1,
    );

    final greetingBoundary = _nextGreetingBoundaryAfter(localDateTime);

    if (greetingBoundary.isBefore(nextMidnight)) {
      return greetingBoundary;
    }

    return nextMidnight;
  }

  static DateTime _nextGreetingBoundaryAfter(DateTime localDateTime) {
    final year = localDateTime.year;
    final month = localDateTime.month;
    final day = localDateTime.day;
    final hour = localDateTime.hour;

    if (hour < 5) {
      return DateTime(year, month, day, 5);
    }

    if (hour < 12) {
      return DateTime(year, month, day, 12);
    }

    if (hour < 19) {
      return DateTime(year, month, day, 19);
    }

    return DateTime(year, month, day + 1, 5);
  }
}
