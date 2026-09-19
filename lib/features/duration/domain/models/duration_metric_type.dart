enum DurationMetricType {
  sleep(
    code: 'sueno',
    label: 'Sueño',
    sourceDataCode: 'DAT-031',
    averageIndicatorCode: 'IND-02',
    individualIndicatorCode: 'IND-01',
    allowsZeroMinutes: false,
  ),

  behavior(
    code: 'conducta',
    label: 'Conductas',
    sourceDataCode: 'DAT-013',
    averageIndicatorCode: 'IND-05',
    individualIndicatorCode: null,
    allowsZeroMinutes: false,
  ),

  dysregulation(
    code: 'desregulacion',
    label: 'Desregulación emocional',
    sourceDataCode: 'DAT-040',
    averageIndicatorCode: 'IND-07',
    individualIndicatorCode: null,
    allowsZeroMinutes: true,
  );

  const DurationMetricType({
    required this.code,
    required this.label,
    required this.sourceDataCode,
    required this.averageIndicatorCode,
    required this.individualIndicatorCode,
    required this.allowsZeroMinutes,
  });

  final String code;

  final String label;

  final String sourceDataCode;

  final String averageIndicatorCode;

  final String? individualIndicatorCode;

  final bool allowsZeroMinutes;

  bool isValidDuration(int? durationMinutes) {
    if (durationMinutes == null) {
      return false;
    }

    if (allowsZeroMinutes) {
      return durationMinutes >= 0;
    }

    return durationMinutes > 0;
  }
}
