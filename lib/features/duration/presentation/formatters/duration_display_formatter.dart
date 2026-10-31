import '../../domain/models/duration_metric_type.dart';

/// Formatea duraciones descriptivas de manera uniforme en Sendaris.
///
/// - Sueño: horas, minutos y segundos cuando corresponda.
/// - Conducta y desregulación: minutos y segundos cuando corresponda.
/// - Los cálculos originales no se modifican.
/// - Se redondea únicamente la representación al segundo más cercano.
abstract final class DurationDisplayFormatter {
  static String format(DurationMetricType type, double minutes) {
    if (!minutes.isFinite || minutes < 0) {
      return 'Sin datos';
    }

    final totalSeconds = (minutes * 60).round();
    final seconds = totalSeconds % 60;
    final parts = <String>[];

    if (type == DurationMetricType.sleep) {
      final hours = totalSeconds ~/ 3600;
      final remainingMinutes = (totalSeconds % 3600) ~/ 60;

      if (hours > 0) {
        parts.add('$hours h');
      }

      if (remainingMinutes > 0 || hours == 0) {
        parts.add('$remainingMinutes min');
      }
    } else {
      final totalMinutes = totalSeconds ~/ 60;
      parts.add('$totalMinutes min');
    }

    if (seconds > 0) {
      parts.add('$seconds s');
    }

    return parts.join(' ');
  }
}
