class ComparisonPeriod {
  ComparisonPeriod({required DateTime startDate, required DateTime endDate})
    : startDate = DateTime(startDate.year, startDate.month, startDate.day),
      endDate = DateTime(endDate.year, endDate.month, endDate.day) {
    if (this.startDate.isAfter(this.endDate)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'La fecha inicial no puede ser posterior '
            'a la fecha final.',
      );
    }
  }

  final DateTime startDate;
  final DateTime endDate;
}
